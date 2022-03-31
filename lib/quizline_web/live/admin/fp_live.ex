defmodule QuizlineWeb.Admin.FPLive do
  use QuizlineWeb, :live_view

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin
  import QuizlineWeb.InputHelpers
  alias Quizline.AdminManager.Guardian

  def mount(params, _session, socket) do
    case params do
      %{"token" => token} ->
        case Guardian.resource_from_token(token) do
          {:ok, %Admin{} = admin, _claims} ->
            {:ok,
             socket
             |> assign(:fpset_changeset, AdminManager.fpset_change_admin(%Admin{}))
             |> assign(:admin, admin)}

          {:error, _} ->
            {:ok, socket |> redirect(to: "/error")}
        end

      _ ->
        {:ok, socket |> redirect(to: "/error")}
    end
  end

  def handle_event("fpset-validate", %{"admin" => params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.fpset_change_admin(params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(fpset_changeset: changeset)}
  end

  def handle_event("fpset-submit", %{"admin" => params}, socket) do
    admin = socket.assigns.admin

    changeset =
      %Admin{}
      |> AdminManager.fpset_change_admin(params)
      |> Map.put(:action, :validate)

    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{hashed_password: password}} ->
        case AdminManager.update_password(admin.id, password) do
          {:ok, true} -> {:noreply, socket |> redirect(to: "/")}
          {:error, _} -> {:noreply, socket |> redirect(to: "/error")}
        end

      %Ecto.Changeset{valid?: false} ->
        {:noreply, socket |> assign(fpset_changeset: changeset)}
    end
  end
end
