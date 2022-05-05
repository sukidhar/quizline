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

  def handle_event("event-file-changed", _, socket) do
    {:noreply, socket}
  end

  def handle_event("event-file-uploaded", _, socket) do
    [data] =
      consume_uploaded_entries(socket, :events_file, fn %{path: path}, _entry ->
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

        {:ok, data}
      end)

    data =
      data
      |> CSV.Encoding.Encoder.encode()
      |> CSV.decode(headers: true, validate_row_length: false)
      |> Enum.to_list()
      |> Enum.map(fn k ->
        case k do
          {:ok,
           %{
             "Branch" => branches,
             "Date" => date,
             "Start Time" => start_time,
             "End Time" => end_time,
             "Subject Code" => subject,
             "Semester" => semesters,
             "Exam Group" => exam_group
           }}
          when is_bitstring(semesters) and is_bitstring(branches) ->
            if is_valid_date(date) and is_valid_timings(start_time, end_time) do
              %{
                subject: subject,
                exam_group: exam_group,
                attendees: [
                  %{
                    branch: branches,
                    semester: semesters
                  }
                ],
                date: parse_date(date),
                start_time: parse_time(start_time),
                end_time: parse_time(end_time)
              }
            else
              nil
            end

          {:ok,
           %{
             "Branch" => branches,
             "Date" => date,
             "Start Time" => start_time,
             "End Time" => end_time,
             "Subject Code" => subject,
             "Semester" => semesters,
             "Exam Group" => exam_group
           }}
          when is_list(semesters) and is_list(branches) and
                 length(semesters) == length(branches) ->
            if is_valid_date(date) and is_valid_timings(start_time, end_time) do
              %{
                subject: subject,
                exam_group: exam_group,
                attendees:
                  Enum.zip(branches, semesters)
                  |> Enum.map(fn k ->
                    case k do
                      {_branch, ""} ->
                        nil

                      {"", ""} ->
                        nil

                      {"", sem} ->
                        %{branch: nil, semester: sem}

                      {branch, sem} ->
                        %{branch: branch, semester: sem}
                    end
                  end)
                  |> Enum.reject(&is_nil/1),
                date: parse_date(date),
                start_time: parse_time(start_time),
                end_time: parse_time(end_time)
              }
            else
              nil
            end

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    send(self(), %{event: "create-bulk-exams", data: data})

    {:noreply, socket}
  end

  defp parse_date(date) do
    res = Timex.parse!(date, "{D}/{M}/{YYYY}") |> Timex.to_unix()
    "#{res}"
  end

  defp parse_time(time) do
    Timex.parse!(time, "{_h24}:{m}")
    |> Timex.to_datetime()
    |> DateTime.to_time()
    |> Time.to_iso8601()
  end

  def is_valid_date(date) do
    res =
      Timex.parse!(date, "{D}/{M}/{YYYY}")
      |> Timex.to_date()
      |> Date.compare(Date.utc_today())

    res in [:gt]
  end

  def is_valid_timings(s, e) do
    s =
      Timex.parse!(s, "{_h24}:{m}")
      |> Timex.to_datetime()
      |> DateTime.to_time()

    e =
      Timex.parse!(e, "{_h24}:{m}")
      |> Timex.to_datetime()
      |> DateTime.to_time()

    Time.compare(s, e) in [:lt]
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
