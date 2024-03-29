defmodule QuizlineWeb.Admin.SessionLive.UsersComponent do
  use QuizlineWeb, :live_component
  import QuizlineWeb.InputHelpers

  alias Phoenix.LiveView.JS
  alias Quizline.AdminManager.Admin
  alias Quizline.UserManager.Student
  alias Quizline.UserManager.Invigilator

  def update(
        %{
          admin: %Admin{id: _id},
          users_data: %{departments: deps, branches: branches, semesters: semesters} = users_data
        } = assigns,
        socket
      ) do
    if is_nil(deps) or is_nil(branches) or is_nil(semesters) do
      send(self(), :load_data)
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       users_data
       |> Enum.map(fn {key, value} ->
         {if(is_atom(key), do: key, else: String.to_existing_atom(key)), value}
       end)
     )
     |> allow_upload(:users_file, accept: ~w(.csv), max_entries: 1)}
  end

  def show_form(atom, js \\ %JS{}) do
    case atom do
      atom when atom in [:student, :invigilator] ->
        js
        |> JS.remove_class("flex",
          to: "#" <> Atom.to_string(alternative_atom(atom)) <> "-add-form-container"
        )
        |> JS.add_class("hidden",
          to: "#" <> Atom.to_string(alternative_atom(atom)) <> "-add-form-container"
        )
        |> JS.remove_class("hidden",
          to: "#" <> Atom.to_string(atom) <> "-add-form-container"
        )
        |> JS.add_class("flex",
          to: "#" <> Atom.to_string(atom) <> "-add-form-container"
        )

      _ ->
        nil
    end
  end

  def alternative_atom(:student) do
    :invigilator
  end

  def alternative_atom(:invigilator) do
    :student
  end

  def hide_form(atom, js \\ %JS{}) do
    case atom do
      atom when atom in [:student, :invigilator] ->
        js
        |> JS.remove_class("flex",
          to: "#" <> Atom.to_string(atom) <> "-add-form-container"
        )
        |> JS.add_class("hidden",
          to: "#" <> Atom.to_string(atom) <> "-add-form-container"
        )

      _ ->
        nil
    end
  end

  def handle_event("show-form", %{"type" => type}, socket) do
    type = String.downcase(type) |> String.to_atom()

    if type in [:student, :invigilator] do
      send(self(), %{show_form: type})
    end

    {:noreply, socket}
  end

  def handle_event("set-form-mode", %{"type" => type}, socket) do
    case type do
      "file" ->
        send(self(), %{form_mode: :file, map: :users_data})

      _ ->
        send(self(), %{form_mode: :form, map: :users_data})
    end

    {:noreply, socket}
  end

  def handle_event("users-file-changed", _, socket) do
    {:noreply, socket}
  end

  def handle_event("users-file-uploaded", _, socket) do
    [data] =
      consume_uploaded_entries(socket, :users_file, fn %{path: path}, _entry ->
        data =
          File.stream!(path)
          |> CSV.decode(validate_row_length: false, strip_fields: true)
          |> Enum.to_list()
          |> Enum.map(fn {:ok, row} ->
            row
          end)
          |> Enum.reject(fn [head | data] ->
            head == "##" or
              ([head] ++ data)
              |> Enum.all?(fn x ->
                x == ""
              end)
          end)
          |> CSV.encode()
          |> CSV.decode!(headers: true)
          |> Enum.to_list()

        {:ok, data}
      end)

    send(self(), %{users_data: data})
    {:noreply, socket}
  end

  def handle_event("invigilator-change", %{"invigilator" => inv_params}, socket) do
    changeset =
      %Invigilator{}
      |> Invigilator.changeset(modify_invigilator_params(inv_params, socket))
      |> Map.put(:action, :insert)

    send(self(), %{changeset: changeset, key: :invigilator_changeset})
    {:noreply, socket}
  end

  def handle_event("invigilator-submit", %{"invigilator" => inv_params}, socket) do
    changeset =
      %Invigilator{}
      |> Invigilator.changeset(modify_invigilator_params(inv_params, socket))
      |> Map.put(:action, :validate)

    send(self(), %{changeset: changeset, key: :invigilator, action: :submit})
    {:noreply, socket}
  end

  def handle_event("student-change", %{"student" => std_params}, socket) do
    changeset =
      %Student{}
      |> Student.changeset(modify_student_params(std_params, socket))
      |> Map.put(:action, :insert)

    send(self(), %{changeset: changeset, key: :student_changeset})
    {:noreply, socket}
  end

  def handle_event("student-submit", %{"student" => std_params}, socket) do
    changeset =
      %Student{}
      |> Student.changeset(modify_student_params(std_params, socket))
      |> Map.put(:action, :validate)

    send(self(), %{changeset: changeset, key: :student, action: :submit})
    {:noreply, socket}
  end

  def id_provider(string) do
    String.downcase(string)
    |> String.split()
    |> Enum.join("-")
  end

  def modify_invigilator_params(params, socket) do
    params
    |> Map.put("department", socket.assigns.selected_department)
    |> Poison.encode!()
    |> Poison.decode!()
  end

  def modify_student_params(params, socket) do
    params
    |> Map.put("semester", socket.assigns.selected_semester)
    |> Map.put("branch", socket.assigns.selected_branch)
    |> Poison.encode!()
    |> Poison.decode!()
  end
end
