defmodule QuizlineWeb.User.Student.ExamRoomLive do
  use QuizlineWeb, :live_view

  alias QuizlineWeb.Presence
  alias Quizline.PubSub
  alias Quizline.EventManager
  alias Quizline.UserManager.{Guardian}

  def mount(%{"room" => room_id}, %{"guardian_default_token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, user, %{"deviceId" => deviceId}} ->
        case EventManager.room_exists?(room_id) do
          false ->
            {:ok, socket |> redirect(to: "/error")}

          true ->
            Phoenix.PubSub.subscribe(PubSub, "exam_session_" <> room_id)

            Presence.track(self(), "exam_session_" <> room_id, user.id, %{
              deviceId: deviceId,
              user_type: :student,
              pid: self(),
              session_start: DateTime.utc_now(),
              approved: false
            })

            {:ok,
             socket
             |> assign(:show_multiple_session_error, false)
             |> assign(:user, user)
             |> assign(:deviceId, deviceId)
             |> assign(:approved, false)
             |> assign(:room_id, room_id)
             |> assign(:is_mic_enabled, true)
             |> assign(:is_video_enabled, true)}
        end

      _ ->
        {:noreply, socket |> redirect(to: "/error")}
    end
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
