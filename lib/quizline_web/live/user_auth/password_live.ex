defmodule QuizlineWeb.UserAuth.PasswordLive do
  use QuizlineWeb, :live_view
  import QuizlineWeb.InputHelpers
  alias Quizline.UserManager
  alias Quizline.UserManager.User
  alias Quizline.UserManager.Guardian

  def mount(%{"token" => token}, _session, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, %User{} = user, _claims} ->
        {:ok,
         socket
         |> assign(:password_changeset, UserManager.password_user_set(%User{}))
         |> assign(:user, user)}

      {:error, _} ->
        {:ok, socket |> redirect(to: "/error")}
    end
  end

  def handle_event("password-validate", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> User.password_changeset(params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(password_changeset: changeset)}
  end

  def handle_event("password-submit", %{"user" => params}, socket) do
    user = socket.assigns.user

    changeset =
      %User{}
      |> UserManager.password_user_set(params)
      |> Map.put(:action, :validate)

    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{hashed_password: password}} ->
        case UserManager.update_password(user.id, password) do
          {:ok, true} -> {:noreply, socket |> redirect(to: "/")}
          {:error, _} -> {:noreply, socket |> redirect(to: "/error")}
        end

      %Ecto.Changeset{valid?: false} ->
        {:noreply, socket |> assign(fpset_changeset: changeset)}
    end
  end
end
