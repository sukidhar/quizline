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

    {:ok,
     socket
     |> assign(assigns)
     # form settings
     |> assign(:form_mode, :file)
     |> allow_upload(:department_file, accept: ~w(.csv), max_entries: 1)
     |> allow_upload(:department_details_file, accept: ~w(.csv), max_entries: 1)
     # confirmation alert params
     |> assign(:confirmation_type, :none)
     |> assign(:deletion_branch_id, "")
     |> assign(:confirmation_title, "")
     |> assign(:confirmation_text, "")
     |> assign(:show_confirmation?, false)
     # department
     |> assign(:selected_department, nil)
     |> assign(:show_dep_form?, false)
     |> assign(:departments, deps)
     |> assign(:selected_tab, :tab_branches)
     |> assign(:changeset, DepartmentManager.department_changeset(%Department{}))
     # invigilators
     |> assign(:invigilators, [])
     |> assign(:selected_invigilator, [])
     # branch
     |> assign(:branches, [])
     |> assign(:show_branch_form?, false)
     |> assign(:new_branch_changeset, DepartmentManager.branch_changeset(%Department.Branch{}))
     # subject
     |> assign(:new_subject_changeset, SubjectManager.subject_changeset(%Subject{}))
     |> assign(:show_subject_form?, false)
     |> assign(:subjects, [])}
  end

  def tab_to_type(tab) do
    case tab do
      :tab_branches -> "branch"
      :tab_subjects -> "subject"
      :tab_invigilators -> "invigilator"
    end
  end

  defp load_subjects(socket) do
    subs =
      SubjectManager.get_subjects(socket.assigns.selected_department.email)
      |> case do
        {:ok, subs} ->
          subs

        {:error, reason, e} ->
          IO.inspect(reason)
          IO.inspect(e)
          []
      end

    socket
    |> assign(:subjects, subs)
  end

  defp load_branches(socket) do
    branches =
      DepartmentManager.get_branches(socket.assigns.selected_department.email)
      |> case do
        {:ok, branches} ->
          branches

        {:error, reason} ->
          IO.inspect(reason)
          []
      end

    socket
    |> assign(:branches, branches)
  end

  def handle_event("department-file-uploaded", _, socket) do
    consume_uploaded_entries(socket, :department_file, fn %{path: path}, _entry ->
      data =
        File.stream!(path)
        |> CSV.decode(strip_fields: true)
        |> Enum.to_list()
        |> Enum.map(fn {:ok, row} ->
          row
        end)

      {:ok, data}
    end)
    |> case do
      [[["Department Title", "Department Email"] | data]] ->
        data
        |> DepartmentManager.create_departments(socket.assigns.admin.id)
        |> case do
          {:ok, deps} ->
            {:noreply,
             socket
             |> assign(:show_dep_form?, false)
             |> assign(
               :departments,
               socket.assigns.departments ++ deps
             )}

          {:error, reason} ->
            IO.inspect(reason)

            {:noreply,
             socket
             |> assign(:show_dep_form?, false)}
        end

      _ ->
        IO.inspect("sorry the format is not matching")
        {:noreply, socket}
    end
  end

  def handle_event("department-file-changed", _, socket) do
    {:noreply, socket}
  end

  def handle_event("department-details-file-changed", _, socket) do
    {:noreply, socket}
  end

  def handle_event("department-details-file-uploaded", _, socket) do
    [data] =
      consume_uploaded_entries(socket, :department_details_file, fn %{path: path}, _entry ->
        data =
          File.stream!(path)
          |> CSV.decode(validate_row_length: false, strip_fields: true)
          |> Enum.to_list()
          |> Enum.map(fn {:ok, row} ->
            row
          end)
          |> Enum.reject(fn [head | data] ->
            head == "#" or
              ([head] ++ data)
              |> Enum.all?(fn x ->
                x == ""
              end)
          end)

        {:ok, data}
      end)

    {branches, subjects} =
      split_before_next(data, "##")
      |> case do
        {:two, data} ->
          {branches, subjects} =
            case data do
              {[["##", "Branches Table" | _] | d1], [["##", "Subjects Table" | _] | d2]} ->
                {parse_branch_data(d1), parse_subject_data(d2)}

              {[["##", "Subjects Table" | _] | d2], [["##", "Branches Table" | _] | d1]} ->
                {parse_branch_data(d1), parse_subject_data(d2)}
            end

          {branches, subjects}

        {:one, data} ->
          case data do
            [["##", "Branches Table" | _] | rows] ->
              {parse_branch_data(rows), []}

            [["##", "Subjects Table" | _] | rows] ->
              {[], parse_subject_data(rows)}
          end

        {:invalid_format} ->
          raise({:invalid_format, "please follow the given format strictly"})
      end

    socket =
      SubjectManager.create_subjects(subjects, socket.assigns.selected_department.email)
      |> case do
        {:ok, _} ->
          load_subjects(socket)

        {:error, reason} ->
          IO.inspect(reason)
          socket
      end

    socket =
      DepartmentManager.create_branches(branches, socket.assigns.selected_department.email)
      |> case do
        {:ok, _} ->
          load_branches(socket)

        {:error, reason} ->
          IO.inspect(reason)
          socket
      end

    {:noreply,
     socket
     |> assign(:show_subject_form?, false)
     |> assign(:show_branch_form?, false)}
  end

  def handle_event("show-add-form", %{"type" => type}, socket) do
    case type do
      "department" ->
        {:noreply, socket |> assign(:show_dep_form?, true)}

      "branch" ->
        {:noreply, socket |> assign(:show_branch_form?, true)}

      "subject" ->
        {:noreply, socket |> assign(:show_subject_form?, true)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("hide-add-form", %{"type" => type}, socket) do
    case type do
      "department" ->
        {:noreply, socket |> assign(:show_dep_form?, false)}

      "branch" ->
        {:noreply, socket |> assign(:show_branch_form?, false)}

      "subject" ->
        {:noreply, socket |> assign(:show_subject_form?, false)}

      _ ->
        {:noreply, socket}
    end
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

  def handle_event("set-form-mode", %{"type" => type}, socket) do
    case type do
      "form" ->
        {:noreply, socket |> assign(:form_mode, :form)}

      "file" ->
        {:noreply, socket |> assign(:form_mode, :file)}

      _ ->
        {:noreply, socket |> assign(:form_mode, :form)}
    end
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
         |> assign(:show_dep_form?, false)
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

    {:noreply,
     socket
     |> assign(:selected_department, department)
     |> load_branches()
     |> load_subjects()}
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
      {:ok, branch} ->
        IO.inspect(branch)

        new_branches = department.branches ++ branch

        {:noreply,
         socket
         |> assign(:selected_department, Map.put(department, :branches, new_branches))
         |> assign(:show_branch_form?, false)
         |> assign(
           :new_branch_changeset,
           DepartmentManager.branch_changeset(%Department.Branch{})
         )}

      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket}

      {:error, _, e} ->
        IO.inspect(e)
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
                  (socket.assigns.branches || [])
                  |> Enum.reject(fn k ->
                    k.branch_id <> "@" <> k.id == id
                  end)

                {:noreply,
                 socket
                 |> assign(:show_confirmation?, false)
                 |> assign(:branches, new_branches)}

              {:error, flash} ->
                IO.inspect(flash)
                {:noreply, socket |> assign(:show_confirmation?, false)}
            end
        end
    end
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
         |> assign(:show_subject_form?, false)
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

  defp split_before_next(data, string) do
    data
    |> Enum.with_index()
    |> Enum.filter(fn k ->
      {ele, _} = k

      case ele do
        [^string | _] -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {_, index} ->
      index
    end)
    |> case do
      [_, index] ->
        {:two, data |> Enum.split(index)}

      [_] ->
        {:one, data}

      [] ->
        {:invalid_format}
    end
  end

  defp parse_branch_data(rows) do
    rows
    |> CSV.Encoding.Encoder.encode()
    |> CSV.decode(headers: true, validate_row_length: false)
    |> Enum.to_list()
    |> Enum.map(fn k ->
      case k do
        {:ok,
         %{
           "Branch Title" => title,
           "Semester" => semester,
           "Subject Code" => subject
         }}
        when is_bitstring(semester) and is_bitstring(subject) ->
          %{title: title, subjects: [%{subject: subject, semester: semester}]}

        {:ok,
         %{
           "Branch Title" => title,
           "Semester" => semesters,
           "Subject Code" => subjects
         }}
        when is_list(semesters) and is_list(subjects) and
               length(semesters) == length(subjects) ->
          %{
            title: title,
            subjects:
              Enum.zip(subjects, semesters)
              |> Enum.map(fn {sub, sem} ->
                %{subject: sub, semester: sem}
              end)
          }

        {:ok, %{"Branch Title" => title}} ->
          %{title: title}

        _ ->
          {:invalid_format}
      end
    end)
  end

  defp parse_subject_data(rows) do
    rows
    |> CSV.Encoding.Encoder.encode()
    |> CSV.decode(headers: true, validate_row_length: false)
    |> Enum.to_list()
    |> Enum.map(fn k ->
      case k do
        {:ok, %{"Subject Title" => title, "Subject Code" => code, "Department Email" => email}} ->
          %{title: title, code: code, email: email}

        {:ok, %{"Subject Title" => title, "Subject Code" => code}} ->
          %{title: title, code: code}

        _ ->
          {:invalid_format}
      end
    end)
  end
end
