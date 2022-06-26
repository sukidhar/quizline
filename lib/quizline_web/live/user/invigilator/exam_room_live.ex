defmodule QuizlineWeb.User.Invigilator.ExamRoomLive do
  use QuizlineWeb, :live_view

  alias Quizline.UserManager.Guardian
  alias QuizlineWeb.Presence

  def mount(%{"room" => room_id}, %{"guardian_default_token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, user, %{"deviceId" => deviceId}} ->
        Phoenix.PubSub.subscribe(PubSub, "exam_session_" <> room_id)

        Presence.track(self(), "exam_session_" <> room_id, user.id, %{
          deviceId: deviceId,
          user_type: :invigilator,
          pid: self(),
          session_start: DateTime.utc_now(),
          approved: false
        })

        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:deviceId, deviceId)
         |> assign(:room_id, room_id)
         |> assign(:peers, [])
         |> assign(:is_mic_enabled, true)
         |> assign(:is_video_enabled, true)}

      _ ->
        {:noreply, socket |> redirect(to: "/error")}
    end
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
end
