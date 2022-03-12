defmodule QuizlineWeb.UserAuth.AuthLive do
  use QuizlineWeb, :live_view

  import QuizlineWeb.InputHelpers
  alias Quizline.UserManager
  alias Quizline.UserManager.User

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:login_changeset, UserManager.login_user_set(%User{}))}
  end

  def handle_event("sign-in-validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> UserManager.login_user_set(user_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(login_changeset: changeset)}
  end

  def handle_event("sign-in-submit", %{"user" => user_params}, socket) do
    case UserManager.authenticate_user(user_params) do
      {:access, user} ->
        {:noreply, redirect(socket, to: "/authenticate/#{UserManager.tokenise_user(user)}")}

      {:error, %{changeset: changeset}} ->
        {:noreply, socket |> assign(login_changeset: changeset)}

      {:error, reason: reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end
end
