defmodule QuizlineWeb.AdminAuthLive do
  use QuizlineWeb, :live_view
  import QuizlineWeb.InputHelper

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin

  def mount(_params, _session, socket) do
    changeset = AdminManager.registration_change_admin(%Admin{})
    {:ok, assign(socket, changeset: changeset)}
  end

  def handle_event("validate", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.registration_change_admin(admin_params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end
end
