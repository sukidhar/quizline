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
    IO.inspect(peers)

    {
      :noreply,
      socket
      |> assign(:peers, peers)
    }
  end

  def handle_event("track-ready", params, socket) do
    IO.inspect(params)

    {
      :noreply,
      push_event(socket, "set-track", params)
    }
  end
end
