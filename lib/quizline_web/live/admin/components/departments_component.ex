defmodule QuizlineWeb.Admin.SessionLive.DepartmentsComponent do
  use QuizlineWeb, :live_component

  import QuizlineWeb.InputHelpers
  alias Quizline.DepartmentManager
  alias Quizline.DepartmentManager.Branch
  alias Quizline.DepartmentManager.Department

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:should_show_add_form, true)
     |> assign(:branches, [])
     |> assign(:changeset, DepartmentManager.department_changeset(%Department{}))}
  end

  def handle_event("show-add-department-form", _, socket) do
    {:noreply, socket |> assign(:should_show_add_form, true)}
  end

  def handle_event("add-new-branch", _, socket) do
    {:noreply,
     socket
     |> assign(
       :branches,
       socket.assigns.branches ++ [DepartmentManager.branch_changeset(%Branch{})]
     )}
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
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:changeset, DepartmentManager.department_changeset(%Department{}))
         |> assign(:should_show_add_form, false)}

      {:error, reason} ->
        IO.inspect(reason)
        socket |> assign(:changeset, changeset)
    end

    {:noreply, socket}
  end
end
