defmodule QuizlineWeb.Admin.SessionLive.DepartmentsComponent do
  use QuizlineWeb, :live_component
  import Ecto.Changeset

  import QuizlineWeb.InputHelpers
  alias Quizline.DepartmentManager
  # alias Quizline.DepartmentManager.Branch
  alias Quizline.DepartmentManager.Department
  alias Quizline.AdminManager.Admin
  alias Quizline.SubjectManager
  alias Quizline.SubjectManager.Subject

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
     # confirmation alert params
     |> assign(:confirmation_type, :none)
     |> assign(:deletion_branch_id, "")
     |> assign(:confirmation_title, "")
     |> assign(:confirmation_text, "")
     |> assign(:show_confirmation?, false)
     # department
     |> assign(:selected_department, nil)
     |> assign(:should_show_add_form, false)
     |> assign(:departments, departments)
     |> assign(:selected_tab, :tab_subjects)
     |> assign(:changeset, DepartmentManager.department_changeset(%Department{}))
     # invigilators
     |> assign(:invigilators, [])
     |> assign(:selected_invigilator, [])
     # branch
     |> assign(:show_add_branch_form?, false)
     |> assign(:new_branch_changeset, DepartmentManager.branch_changeset(%Department.Branch{}))
     # subject
     |> assign(:new_subject_changeset, SubjectManager.subject_changeset(%Subject{}))
     |> assign(:show_add_subject_form?, true)
     |> assign(:subjects, [])}
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

    {:ok, subjects} = SubjectManager.get_subjects(department.email)

    {:noreply,
     socket
     |> assign(:selected_department, department)
     |> assign(:subjects, subjects)}
  end

  def handle_event("deselect-department", _, socket) do
    {:noreply, socket |> assign(:selected_department, nil)}
  end

  def handle_event("refresh-current-department", _, socket) do
    {:noreply, socket}
  end

  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:selected_tab, String.to_atom("tab_" <> tab))}
  end

  def handle_event("show-add-branch-form", _, socket) do
    {:noreply, socket |> assign(:show_add_branch_form?, true)}
  end

  def handle_event("hide-add-branch-form", _, socket) do
    {:noreply, socket |> assign(:show_add_branch_form?, false)}
  end

  def handle_event("new-branch-change", %{"branch" => branch_params}, socket) do
    changeset =
      %Department.Branch{}
      |> DepartmentManager.branch_changeset(branch_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(:new_branch_changeset, changeset)}
  end

  def handle_event("new-branch-submit", %{"branch" => branch_params}, socket) do
    changeset =
      %Department.Branch{}
      |> DepartmentManager.branch_changeset(branch_params)
      |> Map.put(:action, :validate)

    department = socket.assigns.selected_department

    case DepartmentManager.create_branch(changeset, department.email) do
      {:ok, response} ->
        IO.inspect(response)

        new_branches =
          department.branches ++
            [
              %Department.Branch{
                id: changeset.changes.id,
                title: changeset.changes.title,
                branch_id: changeset.changes.branch_id
              }
            ]

        {:noreply,
         socket
         |> assign(:selected_department, Map.put(department, :branches, new_branches))
         |> assign(:show_add_branch_form?, false)
         |> assign(
           :new_branch_changeset,
           DepartmentManager.branch_changeset(%Department.Branch{})
         )}

      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket}
    end
  end

  def handle_event("delete-branch", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:deletion_branch_id, id)
     |> assign(:confirmation_type, :branch_deletion)
     |> assign(:confirmation_title, "Delete Branch?")
     |> assign(
       :confirmation_text,
       "Are you sure to delete this branch? Kindly note this action is irreversible."
     )
     |> assign(:show_confirmation?, true)}
  end

  def handle_event("cancel", _, socket) do
    {:noreply, socket |> assign(:show_confirmation?, false)}
  end

  def handle_event("confirm", _, socket) do
    department = socket.assigns.selected_department

    case socket.assigns.confirmation_type || :none do
      :none ->
        {:noreply, socket |> assign(:show_confirmation?, false)}

      :branch_deletion ->
        case Map.get(socket.assigns, :deletion_branch_id) do
          nil ->
            {:noreply, socket |> assign(:show_confirmation?, false)}

          id ->
            case DepartmentManager.delete_branch(id) do
              {:ok, flash} ->
                IO.inspect(flash)

                new_branches =
                  (department.branches || [])
                  |> Enum.reject(fn k ->
                    k.id == id
                  end)

                {:noreply,
                 socket
                 |> assign(:show_confirmation?, false)
                 |> assign(:selected_department, Map.put(department, :branches, new_branches))}

              {:error, flash} ->
                IO.inspect(flash)
                {:noreply, socket |> assign(:show_confirmation?, false)}
            end
        end
    end
  end

  def handle_event("show-add-subject-form", _, socket) do
    {:noreply, socket |> assign(:show_add_subject_form?, true)}
  end

  def handle_event("hide-add-subject-form", _, socket) do
    {:noreply, socket |> assign(:show_add_subject_form?, false)}
  end

  def handle_event("add-subject-assoc", _, socket) do
    existing_assocs = Map.get(socket.assign.new_subject_changeset.changes.associates, [])

    new_assocs = existing_assocs ++ [SubjectManager.associate_changeset(%Subject.Associate{})]

    changeset = socket.assigns.new_subject_changeset |> put_embed(:associates, new_assocs)

    {:noreply, socket |> assign(:new_subject_changeset, changeset)}
  end

  def handle_event("new-subject-change", %{"subject" => subject_params}, socket) do
    changeset =
      %Subject{}
      |> SubjectManager.subject_changeset(subject_params)
      |> Map.put(:action, :insert)

    IO.inspect(changeset)

    {:noreply, socket |> assign(:new_subject_changeset, changeset)}
  end

  def handle_event("new-subject-submit", %{"subject" => subject_params}, socket) do
    department = socket.assigns.selected_department

    changeset =
      %Subject{}
      |> SubjectManager.subject_changeset(subject_params)
      |> Map.put(:action, :validate)

    changeset
    |> SubjectManager.create_subject(department.email)
    |> case do
      {:ok, subjects} ->
        {:noreply,
         socket
         |> assign(subjects: socket.assigns.subjects ++ subjects)
         |> assign(
           :new_subject_changeset,
           SubjectManager.subject_changeset(%Subject{})
         )}

      {:error, changeset} ->
        {:noreply, socket |> assign(:new_subject_changeset, changeset)}

      {:error, _, reason} ->
        IO.inspect(reason)
        {:noreply, socket}
    end
  end
end
