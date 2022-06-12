defmodule QuizlineWeb.User.Invigilator.ExamRoomLive do
  use QuizlineWeb, :live_view

  def mount(%{"room" => room_id}, _, socket) do
    {:ok,
     socket
     |> assign(:room_id, room_id)
     |> assign(:peers, [])
     |> assign(:is_mic_enabled, true)
     |> assign(:is_video_enabled, true)}
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
