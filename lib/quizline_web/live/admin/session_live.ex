defmodule QuizlineWeb.Admin.SessionLive do
  use QuizlineWeb, :live_view

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin
  alias Quizline.UserManager.Student
  alias Quizline.EventManager
  alias Quizline.EventManager.Exam
  alias Quizline.SubjectManager
  import Quizline.Calendar

  @impl true
  def mount(_params, %{"guardian_default_token" => token}, socket) do
    {:ok, %Admin{} = admin, _claims} = AdminManager.Guardian.resource_from_token(token)

    {:ok,
     socket
     |> assign(:admin, admin)
     |> assign(:view, :events)
     |> allow_upload(:form_sheet, accept: ~w(.csv), max_entries: 1)
     |> assign(:events_data, %{
       events: nil,
       primary_changeset: EventManager.exam_primary_changeset(%Exam{}),
       secondary_changeset: EventManager.exam_secondary_changeset(%Exam{}),
       show_event_form?: false,
       form_mode: :file,
       form_step: :primary,
       selected_subject: nil,
       subjects: nil,
       current_tab: :tab_upcoming,
       calendar_open: false,
       subject_filter: "",
       calendar: calendar_info(Date.utc_today(), Date.utc_today()),
       # specific event
       selected_event: nil,
       selected_room: nil,
       room_members_view: :students,
       student_search_results: []
     })}
  end

  defp view_to_string(view) do
    case view do
      "dashboard" -> :dashboard
      "events" -> :events
      "semesters" -> :semesters
      "departments" -> :departments
      "users" -> :users
    end
  end

  @impl true
  def handle_event("sign-out", _params, socket) do
    {:noreply, socket |> redirect(to: "/signout")}
  end

  def handle_event("show-view", %{"view" => view}, socket) do
    {:noreply, socket |> assign(:view, view_to_string(view))}
  end

  def handle_event("search-field-changed", %{"filter" => text, "event" => event}, socket) do
    case event do
      "student-search" ->
        case socket.assigns.events_data.selected_event do
          nil ->
            {:noreply, socket}

          event ->
            lv = self()

            Task.start_link(fn ->
              res = EventManager.find_students(text, event.id)
              send(lv, %{student_search_results: res})
            end)

            {:noreply, socket}
        end

        {:noreply,
         socket
         |> assign(:events_data, socket.assigns.events_data |> Map.put(:subject_filter, text))}

      "subject-search" ->
        IO.inspect("subject search")

        {:noreply,
         socket
         |> assign(:events_data, socket.assigns.events_data |> Map.put(:subject_filter, text))}
    end
  end

  def handle_event("select-subject", %{"subCode" => sub_code}, socket) do
    events = socket.assigns.events_data

    {sub, _} =
      events.subjects
      |> Enum.find(nil, fn {k, _} ->
        k.subject_code == sub_code
      end)

    send(self(), %{subject: sub})

    {:noreply, socket}
  end

  def handle_event("deselect-subject", _, socket) do
    send(self(), %{subject: nil})
    {:noreply, socket}
  end

  # events tab
  @impl true
  def handle_info(:load_events_and_subjects, socket) do
    subjects =
      case SubjectManager.get_all_subjects(socket.assigns.admin.id) do
        {:error, _, e} ->
          IO.inspect(e)
          []

        data ->
          data
      end

    events =
      case EventManager.fetch_exams(socket.assigns.admin.id) do
        {:error, e} ->
          IO.inspect(e)
          []

        data ->
          data
      end

    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data |> Map.put(:subjects, subjects) |> Map.put(:events, events)
     )}
  end

  @impl true
  def handle_info({:current_tab, tab}, socket) do
    {:noreply,
     socket |> assign(:events_data, socket.assigns.events_data |> Map.put(:current_tab, tab))}
  end

  @impl true
  def handle_info(%{subject: sub}, socket) do
    {:noreply,
     socket |> assign(:events_data, socket.assigns.events_data |> Map.put(:selected_subject, sub))}
  end

  @impl true
  def handle_info({:calendar_open, value}, socket) do
    {:noreply,
     socket |> assign(:events_data, socket.assigns.events_data |> Map.put(:calendar_open, value))}
  end

  @impl true
  def handle_info({:form_mode, mode}, socket) do
    {:noreply,
     socket |> assign(:events_data, socket.assigns.events_data |> Map.put(:form_mode, mode))}
  end

  @impl true
  def handle_info({:show_event_form?, value}, socket) do
    {:noreply,
     socket
     |> assign(:events_data, socket.assigns.events_data |> Map.put(:show_event_form?, value))}
  end

  @impl true
  def handle_info([primary_changeset: changeset, form_step: form_step], socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:primary_changeset, changeset)
       |> Map.put(:form_step, form_step)
     )}
  end

  @impl true
  def handle_info({:primary_changeset, changeset}, socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:primary_changeset, changeset)
     )}
  end

  @impl true
  def handle_info({:secondary_changeset, changeset}, socket) do
    # IO.inspect(changeset)

    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:secondary_changeset, changeset)
     )}
  end

  @impl true
  def handle_info([calendar: info, calendar_open: value], socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:calendar, info)
       |> Map.put(:calendar_open, value)
     )}
  end

  @impl true
  def handle_info(%{event_form_step: step}, socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:form_step, step)
     )}
  end

  @impl true
  def handle_info(%{event: "create-exam", data: data}, socket) do
    case EventManager.create_exam(data, socket.assigns.admin.id) do
      :ok ->
        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.put(:events, nil)
           |> Map.put(:primary_changeset, EventManager.exam_primary_changeset(%Exam{}))
           |> Map.put(:secondary_changeset, EventManager.exam_secondary_changeset(%Exam{}))
           |> Map.put(:show_event_form?, false)
         )}

      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{event: "create-bulk-exams", data: data}, socket) do
    case EventManager.create_exams(data, socket.assigns.admin.id) do
      :ok ->
        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.put(:events, nil)
           |> Map.put(:show_event_form?, false)
         )}

      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{selected_event: nil}, socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:selected_event, nil)
       |> Map.put(:selected_room, nil)
     )}
  end

  def handle_info(%{delete_event: id}, socket) do
    case EventManager.delete_exam(id) do
      {:error, error} ->
        IO.inspect(error)

        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
         )}

      false ->
        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
         )}

      true ->
        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.update!(:events, fn events ->
             events
             |> Enum.reject(fn event ->
               event.id == id
             end)
           end)
         )}
    end
  end

  @impl true
  def handle_info(%{selected_event: event}, socket) do
    case EventManager.get_event_details(event.id) do
      {:error, e} ->
        IO.inspect(e)

        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.put(:selected_event, event)
         )}

      rooms ->
        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.put(:selected_event, event |> Map.put(:rooms, rooms))
         )}
    end
  end

  @impl true
  def handle_info(%{selected_room: nil}, socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:selected_room, nil)
     )}
  end

  @impl true
  def handle_info(%{selected_room: room}, socket) do
    case EventManager.get_room_details(room.id) do
      {:error, e} ->
        IO.inspect(e)

        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.put(:selected_room, room)
         )}

      [room] ->
        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.put(:selected_room, room)
         )}
    end
  end

  @impl true
  def handle_info(%{room_members_view: type}, socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:room_members_view, type)
     )}
  end

  @impl true
  def handle_info(%{student_id: student_id, room: room, action: action}, socket) do
    case action do
      :add ->
        case EventManager.add_student_to_room(student_id, room.id) do
          {:error, error} ->
            IO.inspect(error)

            {:noreply,
             socket
             |> assign(
               :events_data,
               socket.assigns.events_data
             )}

          false ->
            {:noreply,
             socket
             |> assign(
               :events_data,
               socket.assigns.events_data
             )}

          student ->
            students = socket.assigns.events_data.selected_room.students

            students = students ++ [student]

            {:noreply,
             socket
             |> assign(
               :events_data,
               socket.assigns.events_data
               |> Map.update!(:selected_room, fn room ->
                 room |> Map.put(:students, students)
               end)
               |> Map.update!(:student_search_results, fn results ->
                 Enum.map(results, fn %{student: std, assigned: assigned} ->
                   if student.id == std.id do
                     %{student: std, assigned: true}
                   else
                     %{student: std, assigned: assigned}
                   end
                 end)
               end)
             )}
        end

      :remove ->
        case EventManager.remove_student_from_room(student_id, room.id) do
          {:error, error} ->
            IO.inspect(error)

            {:noreply,
             socket
             |> assign(
               :events_data,
               socket.assigns.events_data
             )}

          false ->
            {:noreply,
             socket
             |> assign(
               :events_data,
               socket.assigns.events_data
             )}

          true ->
            students = socket.assigns.events_data.selected_room.students

            students =
              students
              |> Enum.reject(fn %Student{id: id} ->
                id == student_id
              end)

            {:noreply,
             socket
             |> assign(
               :events_data,
               socket.assigns.events_data
               |> Map.update!(:selected_room, fn room ->
                 room |> Map.put(:students, students)
               end)
             )}
        end
    end
  end

  def handle_info(%{student_search_results: res}, socket) do
    {:noreply,
     socket
     |> assign(
       :events_data,
       socket.assigns.events_data
       |> Map.put(:student_search_results, res)
     )}
  end
end
