defmodule QuizlineWeb.Admin.SessionLive.EventsComponent do
  use QuizlineWeb, :live_component

  alias Quizline.AdminManager.Admin
  alias Quizline.EventManager.Exam
  # alias Quizline.SubjectManager
  alias Quizline.SubjectManager.Subject
  # alias Quizline.DepartmentManager.Department
  alias Quizline.EventManager
  import QuizlineWeb.InputHelpers
  import Quizline.Calendar

  def update(%{admin: %Admin{id: _id}, events_data: events_data} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       events_data
       |> Enum.map(fn {key, value} ->
         {if(is_atom(key), do: key, else: String.to_existing_atom(key)), value}
       end)
     )
     |> allow_upload(:events_file, accept: ~w(.csv), max_entries: 1)}
  end

  def handle_event("select-tab", %{"tab" => tab}, socket) do
    send(self(), {:current_tab, ("tab_" <> tab) |> String.to_atom()})
    {:noreply, socket}
  end

  def handle_event("toggle-calendar", _, socket) do
    send(self(), {:calendar_open, !socket.assigns.calendar_open})
    {:noreply, socket}
  end

  def handle_event("show-add-form", _, socket) do
    send(self(), {:show_event_form?, true})
    {:noreply, socket}
  end

  def handle_event("hide-add-form", _, socket) do
    send(self(), {:show_event_form?, false})
    {:noreply, socket}
  end

  def handle_event("set-form-mode", %{"type" => type}, socket) do
    case type do
      "file" ->
        send(self(), {:form_mode, :file})

      _ ->
        send(self(), {:form_mode, :form})
    end

    {:noreply, socket}
  end

  def handle_event("primary-change", %{"exam" => event_params}, socket) do
    changeset =
      %Exam{}
      |> EventManager.exam_primary_changeset(event_params)
      |> Map.put(:action, :insert)

    send(self(), {:primary_changeset, changeset})
    {:noreply, socket}
  end

  def handle_event("secondary-change", %{"exam" => event_params}, socket) do
    params = modify_event_params(event_params, socket)

    changeset =
      %Exam{}
      |> EventManager.exam_secondary_changeset(params)
      |> Map.put(:action, :insert)

    send(self(), {:secondary_changeset, changeset})
    {:noreply, socket}
  end

  def handle_event("primary-submit", %{"exam" => event_params}, socket) do
    changeset =
      %Exam{}
      |> EventManager.exam_primary_changeset(event_params)
      |> Map.put(:action, :validate)

    case changeset do
      %Ecto.Changeset{valid?: true} ->
        send(self(), primary_changeset: changeset, form_step: :secondary)
        {:noreply, socket}

      %Ecto.Changeset{valid?: false} ->
        send(self(), {:primary_changeset, changeset})
        {:noreply, socket}
    end
  end

  def handle_event("secondary-submit", %{"exam" => event_params}, socket) do
    event_params = modify_event_params(event_params, socket)

    changeset =
      %Exam{}
      |> EventManager.exam_secondary_changeset(event_params)
      |> Map.put(:action, :validate)

    case changeset do
      %Ecto.Changeset{valid?: true, changes: secondary} ->
        %Ecto.Changeset{valid?: true, changes: primary} = socket.assigns.primary_changeset
        data = Map.merge(primary, secondary)

        data =
          data
          |> Map.put(
            :attendees,
            Map.get(data, :attendees, [])
            |> Enum.map(fn k ->
              case k do
                %Ecto.Changeset{
                  valid?: true,
                  changes: %{branch: branch, semester: semester, assigned: true}
                } ->
                  %{}
                  |> Map.put(:branch, branch.changes)
                  |> Map.put(:semester, semester.changes)

                _ ->
                  nil
              end
            end)
            |> Enum.reject(&is_nil/1)
          )
          |> Map.put(:subject, %{subject_code: data.subject.changes.subject_code})

        send(self(), %{event: "create-exam", data: data})

      %Ecto.Changeset{valid?: false} ->
        send(self(), {:secondary_changeset, changeset})
    end

    {:noreply, socket}
  end

  def handle_event("change_month", %{"month" => month}, socket) do
    selected_day = get_in(socket.assigns, [:calendar, :selected_day])
    send(self(), calendar: calendar_info(month, selected_day), calendar_open: true)
    {:noreply, socket}
  end

  def handle_event("change_selected_day", %{"date" => date}, socket) do
    send(self(), calendar: calendar_info(date, date), calendar_open: false)
    {:noreply, socket}
  end

  def handle_event("previous-step", _, socket) do
    send(self(), %{event_form_step: :primary})
    {:noreply, socket}
  end

  def subject_code(sub) do
    IO.inspect(sub)

    case sub do
      %Subject{subject_code: code} -> code
      nil -> ""
    end
  end

  defp modify_event_params(event_params, socket) do
    event_params
    |> Map.put(
      "subject",
      case socket.assigns.selected_subject do
        nil ->
          nil

        data ->
          data
      end
    )
    |> Map.put(
      "attendees",
      case socket.assigns.selected_subject do
        nil ->
          nil

        data ->
          data
          |> Map.get(:associates, [])
          |> Enum.with_index()
          |> Enum.map(fn {%{semester: semester, branch: branch}, index} ->
            %{
              "semester" => semester,
              "branch" => branch,
              "assigned" =>
                event_params
                |> Map.get("attendees", %{})
                |> Map.get("#{index}", %{"assigned" => "true"})
                |> Map.get("assigned", "true")
                |> string_to_bool()
            }
          end)
      end
    )
    |> Poison.encode!()
    |> Poison.decode!()
  end

  defp string_to_bool(string) do
    case string do
      "true" -> true
      "false" -> false
    end
  end

  defp branch_title(attendee) do
    attendee.params["branch"]["title"]
    |> case do
      nil -> "Common"
      res -> res
    end
  end

  defp semester_id(attendee) do
    attendee.params["semester"]["sid"]
  rescue
    _e -> ""
  end
end
