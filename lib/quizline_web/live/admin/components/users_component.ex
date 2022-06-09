defmodule QuizlineWeb.Admin.SessionLive.UsersComponent do
  use QuizlineWeb, :live_component
  import QuizlineWeb.InputHelpers

  alias Phoenix.LiveView.JS
  alias Quizline.AdminManager.Admin
  # alias Quizline.UserManager
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
     )}
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

  def handle_event("set-form-mode", %{"type" => type}, socket) do
    case type do
      "file" ->
        send(self(), %{form_mode: :file, map: :users_data})

      _ ->
        send(self(), %{form_mode: :form, map: :users_data})
    end

    {:noreply, socket}
  end

  def handle_event("invigilator-change", %{"invigilator" => inv_params}, socket) do
    changeset =
      %Invigilator{}
      |> Invigilator.changeset(modify_invigilator_params(inv_params, socket))
      |> Map.put(:action, :insert)

    IO.inspect(changeset)

    send(self(), %{changeset: changeset, key: :invigilator_changeset})
    {:noreply, socket}
  end

  def handle_event("invigilator-submit", %{"invigilator" => inv_params}, socket) do
    changeset =
      %Invigilator{}
      |> Invigilator.changeset(modify_invigilator_params(inv_params, socket))
      |> Map.put(:action, :validate)

    send(self(), %{changeset: changeset, key: :invigilator_changeset})
    {:noreply, socket}
  end

  def handle_event("student-change", %{"student" => inv_params}, socket) do
    changeset =
      %Invigilator{}
      |> Invigilator.changeset(inv_params)
      |> Map.put(:action, :insert)

    send(self(), %{changeset: changeset, key: :invigilator_changeset})
    {:noreply, socket}
  end

  def handle_event("student-submit", %{"invigilator" => inv_params}, socket) do
    changeset =
      %Invigilator{}
      |> Invigilator.changeset(inv_params)
      |> Map.put(:action, :validate)

    send(self(), %{changeset: changeset, key: :invigilator_changeset})
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
end
