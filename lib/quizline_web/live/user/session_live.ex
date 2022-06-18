defmodule QuizlineWeb.User.SessionLive do
  use QuizlineWeb, :live_view

  alias Quizline.UserManager.Guardian
  alias Quizline.EventManager

  @impl true
  def mount(_params, %{"guardian_default_token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, user, _} ->
        {:ok,
         socket
         |> assign(:time, DateTime.utc_now())
         |> assign(:timezone, nil)
         |> assign(:should_tick, true)
         |> assign(:user, user)
         |> assign(:view, :events)
         |> assign(:events_data, %{
           events: nil,
           current_tab: :tab_upcoming
         })}
    end
  end

  def view_to_string(view) do
    case view do
      "events" -> :events
      "messages" -> :messages
      "notifications" -> :notifications
      _ -> :events
    end
  end

  @impl true
  def handle_event("show-view", %{"view" => view}, socket) do
    {:noreply, socket |> assign(:view, view_to_string(view))}
  end

  def handle_event("sign-out", _, socket) do
    {:noreply, socket |> redirect(to: "/signout")}
  end

  def handle_event("timezone-callback", %{"timezone" => timezone}, socket) do
    IO.inspect(timezone)
    {:noreply, socket |> assign(:timezone, timezone)}
  end

  @impl true
  def handle_info(:load_events, socket) do
    case EventManager.get_events_for_user(socket.assigns.user.id) do
      {:error, e} ->
        IO.inspect(e)

        {:noreply,
         socket |> assign(:events_data, socket.assigns.events_data |> Map.put(:events, []))}

      data ->
        {:noreply,
         socket
         |> assign(
           :events_data,
           socket.assigns.events_data
           |> Map.put(
             :events,
             data
             |> Enum.sort(&(Date.compare(&1.date, &2.date) in [:lt]))
           )
         )}
    end
  end

  def handle_info({:current_tab, tab}, socket) do
    {:noreply,
     socket |> assign(:events_data, socket.assigns.events_data |> Map.put(:current_tab, tab))}
  end

  def handle_info(:tick, socket) do
    if socket.assigns.should_tick || false do
      Process.send_after(self(), :tick, 5000)
    end

    {:noreply,
     socket
     |> assign(
       :time,
       if is_nil(socket.assigns.timezone) do
         Time.utc_now()
       else
         Timex.now(socket.assigns.timezone)
       end
     )}
  end
end
