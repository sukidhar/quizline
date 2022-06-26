defmodule QuizlineWeb.User.SessionLive do
  use QuizlineWeb, :live_view

  alias Quizline.UserManager.Guardian
  alias Quizline.UserManager.Invigilator
  alias Quizline.UserManager.Student
  alias Quizline.EventManager
  alias QuizlineWeb.Presence
  alias Quizline.PubSub

  @impl true
  def mount(_params, %{"guardian_default_token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, user, %{"deviceId" => deviceId}} ->
        Phoenix.PubSub.subscribe(PubSub, "user_session")

        Presence.track(self(), "user_session", user.id, %{
          deviceId: deviceId,
          user_type:
            case user do
              %Invigilator{} ->
                :invigilator

              %Student{} ->
                :student
            end,
          pid: self(),
          session_start: DateTime.utc_now()
        })

        {:ok,
         socket
         |> assign(:deviceId, deviceId)
         |> assign(:time, DateTime.utc_now())
         |> assign(:timezone, nil)
         |> assign(:should_tick, true)
         |> assign(:user, user)
         |> assign(:view, :messages)
         |> assign(:show_multiple_session_error, false)
         |> assign(:events_data, %{
           events: nil,
           current_tab: :tab_upcoming
         })}

      _ ->
        {:noreply, socket |> redirect(to: "/error")}
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
    {:noreply,
     socket
     |> assign(
       :time,
       if is_nil(socket.assigns.timezone) do
         DateTime.utc_now()
       else
         Timex.now(socket.assigns.timezone)
       end
     )}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff",
          payload: %{joins: joins, leaves: leaves}
        },
        socket
      ) do
    case {Map.keys(joins) |> Enum.find(nil, &(&1 == socket.assigns.user.id)),
          Map.keys(leaves) |> Enum.find(nil, &(&1 == socket.assigns.user.id))} do
      {nil, nil} ->
        {:noreply, socket}

      {jkey, lkey} ->
        if not is_nil(jkey) do
          %{metas: sessions} = Presence.get_by_key("user_session", jkey)

          if Enum.count(sessions |> Enum.frequencies_by(&(&1.deviceId || nil)) |> Map.keys()) > 1 do
            {:noreply, socket |> assign(:show_multiple_session_error, true)}
          else
            {:noreply, socket}
          end
        else
          %{metas: sessions} = Presence.get_by_key("user_session", lkey)

          if Enum.count(sessions |> Enum.frequencies_by(&(&1.deviceId || nil)) |> Map.keys()) <= 1 do
            {:noreply, socket |> assign(:show_multiple_session_error, false)}
          else
            {:noreply, socket}
          end
        end
    end
  end
end
