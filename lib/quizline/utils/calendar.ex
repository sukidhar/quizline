defmodule Quizline.Calendar do
  def calendar_info(month, selected_day) do
    month = cast_to_date(month)
    selected_day = cast_to_date(selected_day)

    %{
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
  end

  def previous_month(%{month: 1} = date), do: %{date | year: date.year - 1, month: 12, day: 1}
  def previous_month(%{month: month} = date), do: %{date | month: month - 1, day: 1}

  def next_month(%{month: 12} = date), do: %{date | year: date.year + 1, month: 1, day: 1}
  def next_month(%{month: month} = date), do: %{date | month: month + 1, day: 1}

  def days_by_week(date) do
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

  def cast_to_date(%Date{} = date), do: date
  def cast_to_date(date), do: Date.from_iso8601!(date)

  def format_selected_date(date) do
    date
    |> cast_to_date()
    |> Calendar.strftime("%b. %d, %Y")
  end
end
