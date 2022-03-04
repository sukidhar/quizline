defmodule QuizlineWeb.AdminAuth.AuthLive do
  use QuizlineWeb, :live_view
  require Logger

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin
  import QuizlineWeb.InputHelpers
  import Quizline.AdminManager.AdminEmailer
  alias QuizlineWeb.Presence
  alias Quizline.PubSub

  def mount(_session, _params, socket) do
    {:ok,
     socket
     |> assign(:show_forgot_password, false)
     |> assign(:show_sign_up, false)
     |> assign(:show_verify_page, false)
     |> assign(:fp_changeset, AdminManager.fp_change_admin(%Admin{}))
     |> assign(:login_changeset, AdminManager.login_change_admin(%Admin{}))
     |> assign(:reg_changeset, AdminManager.registration_change_admin(%Admin{}))}
  end

  def handle_event("sign-in-validate", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.login_change_admin(admin_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(login_changeset: changeset)}
  end

  def handle_event("sign-in-submit", %{"admin" => admin_params}, socket) do
    case AdminManager.authenticate_admin(admin_params) do
      {:access, %Admin{verified: verified} = admin} ->
        if verified do
          {:noreply, redirect(socket, to: "/authenticate/#{AdminManager.tokenise_admin(admin)}")}
        else
          Presence.track(self(), "auth", admin.id, %{
            is_verified: false,
            pid: self()
          })

          Phoenix.PubSub.subscribe(PubSub, "auth")

          deliver_confirmation_instructions(
            admin,
            "http://lvh.me:4000/verify/#{AdminManager.generate_verification_token(admin)}"
          )

          {:noreply, socket |> assign(:user, admin) |> assign(:show_verify_page, true)}
        end

      {:error, reason: reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  def handle_event("sign-up-validate", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.registration_change_admin(admin_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(reg_changeset: changeset)}
  end

  def handle_event("sign-up-submit", %{"admin" => admin_params}, socket) do
    case AdminManager.create_user(admin_params) do
      {:ok, admin} ->
        Presence.track(self(), "auth", admin.id, %{
          is_verified: false,
          pid: self()
        })

        Phoenix.PubSub.subscribe(PubSub, "auth")

        deliver_confirmation_instructions(
          admin,
          "http://lvh.me:4000/verify/#{AdminManager.generate_verification_token(admin)}"
        )

        {:noreply, socket |> assign(:user, admin) |> assign(:show_verify_page, true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(reg_changeset: changeset)}

      {:error, reason} ->
        IO.inspect(reason)
        {:noreply, socket |> put_flash(:error, "email already exists")}
    end
  end

  def handle_event("forgot-password", _params, socket) do
    {:noreply, socket |> assign(:show_forgot_password, true)}
  end

  def handle_event("hide-forgot-password", _params, socket) do
    {:noreply, socket |> assign(:show_forgot_password, false)}
  end

  def handle_event("fp-change", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.fp_change_admin(admin_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(:fp_changeset, changeset)}
  end

  def handle_event("fp-submit", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.fp_change_admin(admin_params)
      |> Map.put(:action, :validate)

    AdminManager.send_fp_instructions(changeset)

    {:noreply,
     socket
     |> assign(:fp_changeset, changeset)
     |> assign(:show_forgot_password, !changeset.valid?)}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff",
          payload: %{joins: joins}
        },
        socket
      ) do
    with %Admin{id: id} <- socket.assigns.user do
      with %{metas: [%{is_verified: status}]} <- joins[id] do
        if status do
          IO.inspect("should redirect from here to authentication route")
        end

        {:noreply, socket}
      else
        _ -> {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end
end
