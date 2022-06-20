defmodule QuizlineWeb.User.SessionLive.EventsComponent do
  use QuizlineWeb, :live_component

  alias Quizline.UserManager.Student
  alias Quizline.EventManager.Exam
  alias Quizline.UserManager.Invigilator

  def update(%{user: _user, events_data: %{events: events} = events_data} = assigns, socket) do
    if is_nil(events) do
      send(self(), :load_events)
    else
      if connected?(socket),
        do: Process.send_after(self(), :tick, 5000)
    end

    {:ok,
     socket
     |> assign(assigns |> Map.delete(:events_data))
     |> assign(
       events_data
       |> Enum.map(fn {key, value} ->
         {if(is_atom(key), do: key, else: String.to_existing_atom(key)), value}
       end)
     )}
  end

  defp display_events(current_tab, events) do
    case current_tab do
      :tab_upcoming ->
        upcoming_events(events)

      :tab_completed ->
        completed_events(events)
    end
  end

  defp upcoming_events(events) do
    events
    |> Enum.filter(fn %Exam{date: date, end_time: end_time} ->
      dt1 =
        ((date |> Date.to_iso8601()) <> "T" <> end_time <> "Z")
        |> Timex.parse!("{ISO:Extended}")
        |> DateTime.to_naive()

      {d, t} = :calendar.local_time()
      {y, mo, d} = d
      {h, m, s} = t
      dt2 = Timex.parse!("#{y}-#{mo}-#{d}T#{h}:#{m}:#{s}", "{YYYY}-{M}-{D}T{_h24}:{_m}:{_s}")
      NaiveDateTime.compare(dt2, dt1) in [:eq, :lt]
    end)
  end

  defp completed_events(events) do
    events
    |> Enum.filter(fn %Exam{date: date, end_time: end_time} ->
      dt =
        ((date |> Date.to_iso8601()) <> "T" <> end_time <> "Z")
        |> Timex.parse!("{ISO:Extended}")
        |> DateTime.to_naive()

      {d, t} = :calendar.local_time()
      {y, mo, d} = d
      {h, m, s} = t
      dt1 = Timex.parse!("#{y}-#{mo}-#{d}T#{h}:#{m}:#{s}", "{YYYY}-{M}-{D}T{_h24}:{_m}:{_s}")

      NaiveDateTime.compare(dt1, dt) in [:gt]
    end)
  end

  def handle_event("select-tab", %{"tab" => tab}, socket) do
    send(self(), {:current_tab, ("tab_" <> tab) |> String.to_atom()})
    {:noreply, socket}
  end

  def handle_event("start-exam-room", %{"room" => room_id}, socket) do
    case socket.assigns.user do
      %Invigilator{} ->
        {:noreply, socket |> push_redirect(to: "/exam/i/#{room_id}")}

      %Student{} ->
        {:noreply, socket |> push_redirect(to: "/exam/#{room_id}")}
    end
  end

  def ftime(time) do
    {:ok, ftime} =
      Time.from_iso8601!(time)
      |> Timex.format("{h12}:{0m} {am}")

    ftime
  rescue
    _ -> time
  end

  def fdate(date, current_date) do
    cond do
      Date.compare(date, current_date |> DateTime.to_date()) in [:eq] ->
        "Today"

      Date.compare(date, tomorrow(current_date)) in [:eq] ->
        "Tomorrow"

      true ->
        date |> Timex.format!("%d-%m-%Y", :strftime)
    end
  end

  defp tomorrow(current_date) do
    d = current_date |> DateTime.to_date()
    %{d | day: d.day + 1}
  end

  def get_room_id(%Exam{rooms: [%Exam.Room{id: room_id} | _]}) do
    room_id
  end

  def get_room_id(_) do
    nil
  end

  # defp yesterday do
  #   d = Date.utc_today()
  #   %{d | day: d.day - 1}
  # end

  def should_show_join(event, current_dt, :tab_upcoming) do
    offset = current_dt.utc_offset

    kh = "#{div(offset, 3600)}"
    km = "#{rem(trunc(offset / 60), 60)}"

    h = if String.length(kh) == 2, do: kh, else: "0" <> kh
    m = if String.length(km) == 2, do: km, else: "0" <> km

    dt =
      ((event.date |> Date.to_iso8601()) <>
         "T" <> event.start_time <> "#{if offset < 0, do: "-", else: "+"}#{h}:#{m}")
      |> Timex.parse!("{ISO:Extended}")

    dt = %DateTime{dt | minute: dt.minute - 15}
    DateTime.compare(current_dt, dt) in [:gt]
  end

  def should_show_join(_event, _current_dt, :tab_completed) do
    false
  end
end
