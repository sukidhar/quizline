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
     )}
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
    event_params =
      event_params
      |> Map.put(
        "subject",
        case socket.assigns.selected_subject do
          nil ->
            nil

          data ->
            data
            |> Map.from_struct()
            |> Enum.into(Map.new(), fn {k, v} -> {Atom.to_string(k), v} end)
        end
      )

    changeset =
      %Exam{}
      |> EventManager.exam_secondary_changeset(event_params)
      |> Map.put(:action, :insert)

    send(self(), {:secondary_changeset, changeset})
    {:noreply, socket}
  end

  def handle_event("primary-submit", %{"exam" => event_params}, socket) do
    changeset =
      %Exam{}
      |> EventManager.exam_primary_changeset(event_params)
      |> Map.put(:action, :validate)

    IO.inspect(changeset)

    case changeset do
      %Ecto.Changeset{valid?: true} ->
        send(self(), primary_changeset: changeset, form_step: :secondary)
        {:noreply, socket}

      %Ecto.Changeset{valid?: false} ->
        send(self(), {:primary_changeset, changeset})
        {:noreply, socket}
    end
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

  def subject_code(sub) do
    IO.inspect(sub)

    case sub do
      %Subject{subject_code: code} -> code
      nil -> ""
    end
  end
end
