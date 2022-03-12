defmodule QuizlineWeb.AdminAuth.AdminSession do
  use QuizlineWeb, :live_view

  # alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin
  alias Quizline.UserManager

  @impl true
  def mount(_params, %{"guardian_default_token" => token}, socket) do
    {:ok, %Admin{} = admin, _claims} = Quizline.AdminManager.Guardian.resource_from_token(token)

    {:ok,
     socket
     |> assign(:admin, admin)
     |> assign(:view, :dashboard)
     |> allow_upload(:form_sheet, accept: ~w(.csv), max_entries: 1)}
  end

  @impl Phoenix.LiveView
  def handle_event("signout", _params, socket) do
    {:noreply, socket |> redirect(to: "/signout")}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    res =
      consume_uploaded_entries(socket, :form_sheet, fn %{path: path}, _entry ->
        [_ | data] = File.stream!(path) |> CSV.decode() |> Enum.to_list()

        rows =
          data
          |> Enum.map(fn k ->
            {:ok, row} = k
            [_, fname, lname, email, acc_type | _] = row

            %{
              first_name: fname,
              last_name: lname,
              email: email,
              account_type: String.downcase(acc_type)
            }
          end)

        {:ok, rows}
      end)
      |> UserManager.create_accounts(socket.assigns.admin.id)

    case res do
      {:ok, users} ->
        Enum.map(users, fn user ->
          IO.inspect(user.email)
        end)

      {:error, reason} ->
        IO.inspect(reason)
    end

    {:noreply, socket}
  end
end
