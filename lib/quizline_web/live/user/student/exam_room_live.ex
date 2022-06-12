defmodule QuizlineWeb.User.Student.ExamRoomLive do
  use QuizlineWeb, :live_view

  def mount(%{"room" => room_id}, _, socket) do
    {:ok,
     socket
     |> assign(:room_id, room_id)
     |> assign(:is_mic_enabled, true)
     |> assign(:is_video_enabled, true)}
  end
end
