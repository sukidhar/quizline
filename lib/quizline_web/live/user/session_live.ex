defmodule QuizlineWeb.User.SessionLive do
  use QuizlineWeb, :live_view

  alias Quizline.UserManager.Guardian

  def mount(_params, %{"guardian_default_token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, user, _} ->
        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:view, :events)}
    end
  end

  def view_to_string(view) do
    case view do
      "events" -> :events
      "messages" -> :messages
      "notifications" -> :notifications
      _ -> :events
    end
  end

  def handle_event("show-view", %{"view" => view}, socket) do
    {:noreply, socket |> assign(:view, view_to_string(view))}
  end

  def handle_event("sign-out", _, socket) do
    {:noreply, socket |> redirect(to: "/signout")}
  end
end
