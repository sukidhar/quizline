defmodule QuizlineWeb.UserAuth.PasswordLive do
  use QuizlineWeb, :live_view

  def mount(params, _session, socket) do
    IO.inspect(params)
    {:ok, socket}
  end
end
