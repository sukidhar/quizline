defmodule QuizlineWeb.User.SessionLive.EventsComponent do
  use QuizlineWeb, :live_component

  def update(%{user: _user} = assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end
end
