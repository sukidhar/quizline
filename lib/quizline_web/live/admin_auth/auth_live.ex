defmodule QuizlineWeb.AdminAuth.AuthLive do
  use QuizlineWeb, :live_view

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin
  import QuizlineWeb.InputHelpers

  def mount(_session, _params, socket) do
    {:ok,
     socket
     |> assign(:changeset, AdminManager.registration_change_admin(%Admin{}))}
  end

  def handle_event("validate", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.registration_change_admin(admin_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(changeset: changeset)}
  end

  def handle_event("submit", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.registration_change_admin(admin_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(changeset: changeset)}
  end
end
