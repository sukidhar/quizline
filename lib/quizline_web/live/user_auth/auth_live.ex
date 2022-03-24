defmodule QuizlineWeb.UserAuth.AuthLive do
  use QuizlineWeb, :live_view

  import QuizlineWeb.InputHelpers
  alias Quizline.UserManager
  alias Quizline.UserManager.User

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_forgot_password, false)
     |> assign(:login_changeset, UserManager.login_user_set(%User{}))
     |> assign(:fp_changeset, UserManager.fp_change_user(%User{}))}
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

  def handle_event("forgot-password", _params, socket) do
    {:noreply, socket |> assign(:show_forgot_password, true)}
  end

  def handle_event("hide-forgot-password", _params, socket) do
    {:noreply, socket |> assign(:show_forgot_password, false)}
  end

  def handle_event("fp-change", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> UserManager.fp_change_user(user_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(:fp_changeset, changeset)}
  end

  def handle_event("fp-submit", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> UserManager.fp_change_user(user_params)
      |> Map.put(:action, :validate)

    UserManager.send_fp_instructions(changeset)

    {:noreply,
     socket
     |> assign(:fp_changeset, changeset)
     |> assign(:show_forgot_password, !changeset.valid?)}
  end
end
