defmodule QuizlineWeb.Admin.SessionLive do
  use QuizlineWeb, :live_view

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin

  @impl true
  def mount(_params, %{"guardian_default_token" => token}, socket) do
    {:ok, %Admin{} = admin, _claims} = AdminManager.Guardian.resource_from_token(token)

    {:ok,
     socket
     |> assign(:admin, admin)
     |> assign(:view, :events)
     |> allow_upload(:form_sheet, accept: ~w(.csv), max_entries: 1)}
  end

  defp view_to_string(view) do
    case view do
      "dashboard" -> :dashboard
      "events" -> :events
      "semesters" -> :semesters
      "departments" -> :departments
      "users" -> :users
    end
  end

  @impl true
  def handle_event("sign-out", _params, socket) do
    {:noreply, socket |> redirect(to: "/signout")}
  end

  def handle_event("show-view", %{"view" => view}, socket) do
    {:noreply, socket |> assign(:view, view_to_string(view))}
  end
end
