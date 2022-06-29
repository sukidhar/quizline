defmodule QuizlineWeb.User.Invigilator.ExamRoomLive do
  use QuizlineWeb, :live_view

  alias Quizline.UserManager.{Guardian, Invigilator}
  alias Quizline.EventManager
  alias QuizlineWeb.Presence
  alias Quizline.PubSub

  def mount(%{"room" => room_id}, %{"guardian_default_token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, %Invigilator{} = user, %{"deviceId" => deviceId}} ->
        case EventManager.get_event(room_id) do
          nil ->
            {:ok, socket |> redirect(to: "/error")}

          exam ->
            Phoenix.PubSub.subscribe(PubSub, "exam_session_" <> room_id)

            Presence.track(self(), "exam_session_" <> room_id, user.id, %{
              deviceId: deviceId,
              pid: self(),
              session_start: DateTime.utc_now()
            })

            Registry.register(Quizline.SessionRegistry, user.id, self())

            {:ok,
             socket
             |> assign(:user, user)
             |> assign(:deviceId, deviceId)
             |> assign(:room_id, room_id)
             |> assign(:exam, exam)
             |> assign(:selected_users, :requests)
             |> assign(:started, false)
             |> assign(:selected_request, nil)
             |> assign(:requests, [])
             |> assign(:attendees, [])
             |> assign(:peers, [])
             |> assign(:show_multiple_session_error, false)
             |> assign(:is_mic_enabled, true)
             |> assign(:is_video_enabled, true)}
        end

      _ ->
        {:ok, socket |> redirect(to: "/auth")}
    end
  end

  def mount(_, _, socket) do
    {:ok, socket |> redirect(to: "/auth")}
  end

  def handle_event("started-room", _, socket) do
    send(self(), :after_started_room)

    {:noreply,
     socket
     |> push_event("join-exam-channel", %{
       user: socket.assigns.user,
       room_id: socket.assigns.room_id
     })}
  end

  def handle_event("joined-rtc-engine", %{"peers" => peers}, socket) do
    {:noreply, socket |> assign(:peers, peers)}
  end

  def handle_event("track-ready", params, socket) do
    {:noreply, push_event(socket, "set-track", params)}
  end

  def handle_event("peer-joined", %{"peer" => new_peer}, socket) do
    {:noreply, socket |> assign(:peers, socket.assigns.peers ++ [new_peer])}
  end

  def handle_event("peer-left", %{"peer" => new_peer}, socket) do
    peers =
      socket.assigns.peers
      |> Enum.reject(fn peer ->
        peer["id"] == new_peer["id"]
      end)

    {:noreply, socket |> assign(:peers, peers)}
  end

  def handle_event("select-users", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(
       :selected_users,
       case type do
         "attendees" -> :attendees
         _ -> :requests
       end
     )}
  end

  @bucket "quizline"
  def generate_query(roomId, userId) do
    client =
      AWS.Client.create(
        System.fetch_env!("SPACES_KEY"),
        System.fetch_env!("SPACES_SECRET"),
        "us-east-1"
      )

    client =
      AWS.Client.put_endpoint(client, "ams3.digitaloceanspaces.com") |> Map.put(:service, "s3")

    url =
      "https://#{client.endpoint}/#{AWS.Util.encode_uri(@bucket)}/#{AWS.Util.encode_uri(roomId)}.#{AWS.Util.encode_uri(userId)}"

    %{
      query: %{
        headers:
          AWS.Signature.sign_v4(
            client,
            NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            :get,
            url,
            [{"Content-Type", "text/xml"}],
            ""
          )
          |> Map.new(),
        url: url
      }
    }
  end

  def handle_event("respond-to-request", %{"response" => res}, socket) do
    req = socket.assigns.selected_request

    case {res, req} do
      {"accept", req} when not is_nil(req) ->
        Presence.update(
          req.pid,
          "exam-channel:" <> socket.assigns.room_id,
          req.user.id,
          req |> Map.put(:status, :approved)
        )

      {"refuse", req} when not is_nil(req) ->
        Presence.update(
          req.pid,
          "exam-channel:" <> socket.assigns.room_id,
          req.user.id,
          req |> Map.put(:status, :refused)
        )

      {_, nil} ->
        nil
    end

    {:noreply, socket |> assign(:selected_request, nil)}
  end

  def handle_event("select-request", %{"id" => id}, socket) do
    request =
      Enum.find(socket.assigns.requests, nil, fn k ->
        k.user.id == id
      end)

    {:noreply, socket |> assign(:selected_request, request)}
  end

  def query_data(request) do
    request.query |> Jason.encode!()
  end

  defp sync_presences(presences, socket) do
    presences =
      presences
      |> Map.delete(socket.assigns.user.id)
      |> Map.values()
      |> Enum.map(fn v ->
        [[h] | _] = v |> Map.values()

        Map.merge(h, generate_query(socket.assigns.room_id, h.user.id))
      end)

    {requests, attendees} = Enum.split_with(presences, &(&1.status == :requested))

    socket
    |> assign(:attendees, attendees)
    |> assign(:requests, requests)
  end

  def handle_info(:after_started_room, socket) do
    {:noreply, socket |> assign(:started, true)}
  end

  def handle_info({:presence_state, presences}, socket) do
    {:noreply, sync_presences(presences, socket)}
  end

  def handle_info({:presence_diff, presences}, socket) do
    {:noreply, sync_presences(presences, socket)}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff",
          payload: %{joins: joins, leaves: leaves}
        },
        socket
      ) do
    case {Map.keys(joins) |> Enum.find(nil, &(&1 == socket.assigns.user.id)),
          Map.keys(leaves) |> Enum.find(nil, &(&1 == socket.assigns.user.id))} do
      {nil, nil} ->
        {:noreply, socket}

      {jkey, lkey} ->
        if not is_nil(jkey) do
          %{metas: sessions} = Presence.get_by_key("exam_session_#{socket.assigns.room_id}", jkey)

          if Enum.count(sessions) > 1 do
            {:noreply, socket |> assign(:show_multiple_session_error, true)}
          else
            {:noreply, socket}
          end
        else
          %{metas: sessions} = Presence.get_by_key("exam_session_#{socket.assigns.room_id}", lkey)

          if Enum.count(sessions) <= 1 do
            {:noreply, socket |> assign(:show_multiple_session_error, false)}
          else
            {:noreply, socket}
          end
        end
    end
  end
end
