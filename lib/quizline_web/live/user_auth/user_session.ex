defmodule QuizlineWeb.UserAuth.UserSession do
  use QuizlineWeb, :live_view

  def handle_event("signout", _, socket) do
    {:noreply, socket |> redirect(to: "/signout")}
  end
end
