defmodule QuizlineWeb.Admin.SessionLive.UsersComponent do
  use QuizlineWeb, :live_component
  import QuizlineWeb.InputHelpers

  alias Quizline.AdminManager.Admin

  def update(%{admin: %Admin{id: _id}} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:show_add_form?, false)}
  end

  def handle_event("show-add-form", _, socket) do
    {:noreply, socket |> assign(:show_add_form?, true)}
  end

  def handle_event("hide-add-form", _, socket) do
    {:noreply, socket |> assign(:show_add_form?, false)}
  end
end
