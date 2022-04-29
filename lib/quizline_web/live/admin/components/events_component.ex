defmodule QuizlineWeb.Admin.SessionLive.EventsComponent do
  use QuizlineWeb, :live_component

  alias Quizline.AdminManager.Admin
  alias Quizline.EventManager.Exam
  alias Quizline.EventManager
  import QuizlineWeb.InputHelpers

  def update(%{admin: %Admin{id: _id}} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:primary_changeset, EventManager.exam_primary_changeset(%Exam{}))
     |> assign(:show_event_form?, true)
     |> assign(:selected_event, nil)
     |> assign(:form_mode, :form)
     |> assign(:subjects, [])
     |> assign(:form_step, :primary)
     |> assign(:current_tab, :tab_upcoming)
     |> assign(:selected_date, nil)
     |> assign(:calendar_open, false)
     |> assign(:calendar, calendar_info(Date.utc_today(), Date.utc_today()))}
  end

  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:current_tab, ("tab_" <> tab) |> String.to_atom())}
  end

  def handle_event("toggle-calendar", _, socket) do
    {:noreply, socket |> assign(:calendar_open, !socket.assigns.calendar_open)}
  end

  def handle_event("show-add-form", _, socket) do
    {:noreply, socket |> assign(:show_event_form?, true)}
  end

  def handle_event("hide-add-form", _, socket) do
    {:noreply, socket |> assign(:show_event_form?, false)}
  end

  def handle_event("set-form-mode", %{"type" => type}, socket) do
    case type do
      "file" ->
        {:noreply, socket |> assign(:form_mode, :file)}

      _ ->
        {:noreply, socket |> assign(:form_mode, :form)}
    end
  end

  def handle_event("primary-change", %{"exam" => event_params}, socket) do
    changeset =
      %Exam{}
      |> EventManager.exam_primary_changeset(event_params)
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(:primary_changeset, changeset)}
  end

  def handle_event("primary-submit", %{"exam" => event_params}, socket) do
    changeset =
      %Exam{}
      |> EventManager.exam_primary_changeset(event_params)
      |> Map.put(:action, :validate)

    IO.inspect(changeset)

    case changeset do
      %Ecto.Changeset{valid?: true} ->
        {:noreply,
         socket
         |> assign(:primary_changset, changeset)
         |> assign(:form_step, :secondary)}

      %Ecto.Changeset{valid?: false} ->
        {:noreply,
         socket
         |> assign(:primary_changset, changeset)}
    end
  end

  def handle_event("change_month", %{"month" => month}, socket) do
    selected_day = get_in(socket.assigns, [:calendar, :selected_day])
    socket = assign(socket, calendar: calendar_info(month, selected_day), calendar_open: true)
    {:noreply, socket}
  end

  def handle_event("change_selected_day", %{"date" => date}, socket) do
    socket = assign(socket, calendar: calendar_info(date, date), calendar_open: false)
    {:noreply, socket}
  end

  defp calendar_info(month, selected_day) do
    month = cast_to_date(month)
    selected_day = cast_to_date(selected_day)

    res = %{
      selected_day: selected_day,
      selected_month: Calendar.strftime(month, "%B"),
      previous_month: previous_month(month),
      next_month: next_month(month),
      days_by_week:
        days_by_week(month)
        |> List.flatten()
        |> Enum.reverse()
        |> Enum.drop_while(&is_nil/1)
        |> Enum.reverse()
        |> Enum.chunk_every(7)
    }

    res
  end

  defp previous_month(%{month: 1} = date), do: %{date | year: date.year - 1, month: 12, day: 1}
  defp previous_month(%{month: month} = date), do: %{date | month: month - 1, day: 1}

  defp next_month(%{month: 12} = date), do: %{date | year: date.year + 1, month: 1, day: 1}
  defp next_month(%{month: month} = date), do: %{date | month: month + 1, day: 1}

  defp days_by_week(date) do
    month_start = Date.beginning_of_month(date)
    month_end = Date.end_of_month(date)

    offset_start = Date.day_of_week(month_start, :sunday) - 1
    offset_end = 7 - Date.day_of_week(month_end, :sunday)

    date_list = Date.range(month_start, month_end) |> Enum.map(& &1)

    padding_start = for _o <- 1..offset_start, do: nil
    padding_end = for _o <- 1..offset_end, do: nil

    padded_month_list = padding_start ++ date_list ++ padding_end
    Enum.chunk_every(padded_month_list, 7)
  end

  defp cast_to_date(%Date{} = date), do: date
  defp cast_to_date(date), do: Date.from_iso8601!(date)

  defp format_selected_date(date) do
    date
    |> cast_to_date()
    |> Calendar.strftime("%b. %d, %Y")
  end
end
