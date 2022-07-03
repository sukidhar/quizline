defmodule QuizlineWeb.Live.User.Invigilator.ChatsLive do
  use QuizlineWeb, :live_view

  def mount(_, _, socket) do
    IO.inspect("invigilator chats live")
    {:ok, socket}
  end
end
