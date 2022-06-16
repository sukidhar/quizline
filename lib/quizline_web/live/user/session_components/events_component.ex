defmodule QuizlineWeb.User.SessionLive.EventsComponent do
  use QuizlineWeb, :live_component

  alias Quizline.UserManager.Student
  alias Quizline.UserManager.Invigilator

  def update(%{user: _user, events_data: %{events: events} = events_data} = assigns, socket) do
    if is_nil(events) do
      send(self(), :load_events)
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
end
