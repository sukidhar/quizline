defmodule QuizlineWeb.Admin.SessionLive.SemestersComponent do
  use QuizlineWeb, :live_component

  alias Quizline.AdminManager.Admin
  alias Quizline.SemesterManager
  alias Quizline.SemesterManager.Semester
  import QuizlineWeb.InputHelpers

  def update(%{admin: %Admin{id: id}} = assigns, socket) do
    {:ok, semesters} = SemesterManager.get_semesters(id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:semesters, semesters)
     |> assign(:changeset, SemesterManager.semester_changeset(%Semester{}))
     |> assign(:show_add_form?, false)}
  end

  def handle_event("show-add-form", _, socket) do
    {:noreply, socket |> assign(:show_add_form?, true)}
  end

  def handle_event("hide-add-form", _, socket) do
    {:noreply, socket |> assign(:show_add_form?, false)}
  end

  def handle_event("form-change", %{"semester" => semester_params}, socket) do
    changeset =
      %Semester{}
      |> SemesterManager.semester_changeset(semester_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("form-submit", %{"semester" => semester_params}, socket) do
    changeset =
      %Semester{}
      |> SemesterManager.semester_changeset(semester_params)
      |> Map.put(:action, :validate)

    changeset
    |> case do
      %Ecto.Changeset{valid?: true, changes: %{title: title, symbol: symbol, id: id} = changes} ->
        common? = Map.get(changes, :common?, false)

        case SemesterManager.create_semester(
               %Semester{
                 title: title,
                 symbol: symbol,
                 id: id,
                 common?: common?
               },
               socket.assigns.admin.id
             ) do
          {:ok, data} ->
            IO.inspect(data)

            {:noreply,
             socket
             |> assign(:semesters, socket.assigns.semesters ++ data)
             |> assign(:show_add_form?, false)
             |> assign(:changeset, SemesterManager.semester_changeset(%Semester{}))}

          {:error, _, e} ->
            IO.inspect(e)

            {:noreply,
             socket |> assign(:changeset, SemesterManager.semester_changeset(%Semester{}))}
        end
    end
  end
end
