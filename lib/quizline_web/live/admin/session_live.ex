defmodule QuizlineWeb.Admin.SessionLive do
  use QuizlineWeb, :live_view

  # alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin
  alias Quizline.UserManager

  @ignore_list ["and"]

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

            [
              _,
              fname,
              lname,
              reg_no,
              semester,
              email,
              acc_type,
              department,
              dep_email,
              branch | _
            ] = row

            %{
              user: %{
                reg_no: reg_no |> String.trim(),
                first_name: fname |> String.trim(),
                last_name: lname |> String.trim(),
                email: String.downcase(email) |> String.trim(),
                account_type: String.downcase(acc_type) |> String.trim(),
                semester: String.trim(semester || "")
              },
              department: %{
                account_type: String.downcase(acc_type) |> String.trim(),
                branch: capitalise_each(branch || "") |> String.trim(),
                title: capitalise_each(department) |> String.trim(),
                email: String.downcase(dep_email) |> String.trim()
              }
            }
          end)

        {:ok, rows}
      end)
      |> UserManager.create_accounts(socket.assigns.admin.id)

    case res do
      {:ok, _users} ->
        # TODO show successful message on website
        IO.inspect("successfully created all accounts")

      {:error, reason} ->
        # TODO show failure message on website
        IO.inspect(reason)
    end

    {:noreply, socket}
  end

  def handle_event("show-dashboard", _, socket) do
    {:noreply, socket |> assign(:view, :dashboard)}
  end

  def handle_event("show-events", _, socket) do
    {:noreply, socket |> assign(:view, :events)}
  end

  def handle_event("show-departments", _, socket) do
    {:noreply, socket |> assign(:view, :departments)}
  end

  def handle_event("show-users", _, socket) do
    {:noreply, socket |> assign(:view, :users)}
  end

  defp capitalise_each(string) do
    string
    |> String.split()
    |> Enum.map(fn k ->
      if k not in @ignore_list, do: String.capitalize(k), else: k
    end)
    |> Enum.join(" ")
  end
end
