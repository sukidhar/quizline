defmodule QuizlineWeb.Live.User.Student.ChatsLive do
  use QuizlineWeb, :live_view

  def mount(_, _, socket) do
    IO.inspect("student chats live")
    {:ok, socket}
  end
end
