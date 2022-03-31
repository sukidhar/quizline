defmodule QuizlineWeb.Admin.SessionLive.DepartmentsComponent do
  use QuizlineWeb, :live_component
  import Ecto.Changeset

  import QuizlineWeb.InputHelpers
  alias Quizline.DepartmentManager
  # alias Quizline.DepartmentManager.Branch
  alias Quizline.DepartmentManager.Department
  alias Quizline.AdminManager.Admin

  def update(%{admin: %Admin{id: id}} = assigns, socket) do
    {:ok, deps} = DepartmentManager.get_departments_with_branches(id)

    departments =
      deps
      |> Enum.map(fn {:ok, dep} ->
        dep
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:selected_department, nil)
     |> assign(:should_show_add_form, false)
     |> assign(:departments, departments)
     |> assign(:changeset, DepartmentManager.department_changeset(%Department{}))}
  end

  def handle_event("show-add-department-form", _, socket) do
    {:noreply, socket |> assign(:should_show_add_form, true)}
  end

  def handle_event("hide-add-form", _, socket) do
    {:noreply, socket |> assign(:should_show_add_form, false)}
  end

  def handle_event("add-branch", _, socket) do
    existing_branches = Map.get(socket.assigns.changeset.changes, :branches, [])

    new_branches =
      existing_branches ++
        [
          DepartmentManager.Department.branch_changeset(
            %DepartmentManager.Department.Branch{},
            %{}
          )
        ]

    changeset = socket.assigns.changeset |> put_embed(:branches, new_branches)

    {:noreply,
     socket
     |> assign(
       :changeset,
       changeset
     )}
  end

  def handle_event("remove-branch", %{"branch_id" => id}, socket) do
    existing_branches = Map.get(socket.assigns.changeset.changes, :branches, [])

    updated_branches =
      existing_branches
      |> Enum.reject(fn %Ecto.Changeset{changes: %{id: branch_id}} ->
        id == branch_id
      end)

    changeset = socket.assigns.changeset |> put_embed(:branches, updated_branches)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("dep-change", %{"department" => department}, socket) do
    changeset =
      %Department{}
      |> DepartmentManager.department_changeset(department)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("dep-submit", %{"department" => department}, socket) do
    changeset =
      %Department{}
      |> DepartmentManager.department_changeset(department)
      |> Map.put(:action, :validate)

    case DepartmentManager.create_department(changeset, socket.assigns.admin.id) do
      {:ok, department} ->
        {:noreply,
         socket
         |> assign(:changeset, DepartmentManager.department_changeset(%Department{}))
         |> assign(:should_show_add_form, false)
         |> assign(:departments, socket.assigns.departments ++ [department])}

      {:error, reason} ->
        IO.inspect(reason)

        {:noreply, socket |> assign(:changeset, changeset)}
    end
  end

  def handle_event("department-pressed", %{"department_email" => email}, socket) do
    departments = socket.assigns.departments

    department =
      Enum.find(departments, fn k ->
        k.email == email
      end)

    {:noreply, socket |> assign(:selected_department, department)}
  end

  def handle_event("deselect-department", _, socket) do
    {:noreply, socket |> assign(:selected_department, nil)}
  end

  def handle_event("refresh-current-department", _, socket) do
    {:noreply, socket}
  end
end
