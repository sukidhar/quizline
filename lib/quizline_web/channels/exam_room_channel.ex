defmodule QuizlineWeb.ExamRoomChannel do
  use QuizlineWeb, :channel
  require Logger

  alias QuizlineWeb.Presence
  alias Quizline.PubSub

  @impl true
  def join("exam_room:" <> room_id, %{"user" => user}, socket) do
    case :global.whereis_name(room_id) do
      :undefined ->
        Quizline.ExamRoom.start(room_id, name: {:global, room_id})

      pid ->
        {:ok, pid}
    end
    |> case do
      {:ok, room_pid} ->
        do_join(socket, room_pid, room_id, user)

      {:error, {:already_started, room_pid}} ->
        do_join(socket, room_pid, room_id, user)

      {:error, reason} ->
        Logger.error("""
        Failed to start room.
        Room: #{inspect(room_id)}
        Reason: #{inspect(reason)}
        """)

        {:error, %{reason: "failed to start room"}}
    end
  end

  defp do_join(socket, room_pid, room_id, user) do
    Process.monitor(room_pid)
    send(self(), :after_join)

    {:ok,
     Phoenix.Socket.assign(socket, %{
       room_id: room_id,
       room_pid: room_pid,
       user: user |> Jason.encode!() |> Jason.decode!(keys: :atoms)
     })}
  end

  @impl true
  def handle_in("mediaEvent", %{"data" => event}, socket) do
    send(socket.assigns.room_pid, {:media_event, socket.assigns.peer_id, event})

    {:noreply, socket}
  end

  def handle_in("start-exam", %{"peer_id" => peer_id}, socket) do
    Process.monitor(socket.assigns.room_pid)
    {:noreply, Phoenix.Socket.assign(socket, %{peer_id: peer_id})}
  end

  def handle_in("reveal_qp", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, _pid, _reason},
        socket
      ) do
    {:stop, :normal, socket}
  end

  @impl true
  def handle_info({:media_event, event}, socket) do
    push(socket, "mediaEvent", %{data: event})

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        :after_join,
        %{assigns: %{room_pid: room_pid, room_id: room_id, user: %{type: type} = user}} = socket
      ) do
    Phoenix.PubSub.subscribe(PubSub, "exam-channel:" <> room_id)

    Presence.track(
      self(),
      "exam-channel:" <> socket.assigns.room_id,
      socket.assigns.user.id,
      %{
        pid: self()
      }
    )

    case type do
      "student" ->
        send(room_pid, {:student, %{channel: self(), user: user |> Map.delete(:type)}})

      "invigilator" ->
        send(room_pid, {:invigilator, %{channel: self(), user: user |> Map.delete(:type)}})
    end

    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff"
        },
        socket
      ) do
    # [{_pid, lv_pid}] = Registry.lookup(Quizline.SessionRegistry, socket.assigns.user.id)
    # send(lv_pid, {:presence_diff, Presence.list("exam-channel:" <> socket.assigns.room_id)})

    {:noreply, socket}
  end
end
