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
             |> assign(:started, false)
             |> assign(:peers, [])
             |> assign(:show_multiple_session_error, false)
             |> assign(:is_mic_enabled, true)
             |> assign(:is_video_enabled, true)}
        end

      _ ->
        {:ok, socket |> redirect(to: "/error")}
    end
  end

  def handle_event("started-room", _, socket) do
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
