defmodule Quizline.ExamRoom do
  @moduledoc false

  use GenServer

  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Message
  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.RTC.Engine.Endpoint.WebRTC.SimulcastConfig
  alias Membrane.ICE.TURNManager
  alias Membrane.WebRTC.Extension.{Mid, Rid, TWCC}

  require Membrane.Logger
  require OpenTelemetry.Tracer, as: Tracer

  @mix_env Mix.env(:dev)

  def start(init_arg, opts) do
    GenServer.start(__MODULE__, init_arg, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(room_id) do
    Membrane.Logger.info("Spawning room process: #{inspect(self())}")

    turn_mock_ip = Application.fetch_env!(:quizline, :integrated_turn_ip)
    turn_ip = if @mix_env == :prod, do: {0, 0, 0, 0}, else: turn_mock_ip

    trace_ctx = create_context("exam_room:#{room_id}")

    rtc_engine_options = [
      id: room_id,
      trace_ctx: trace_ctx
    ]

    turn_cert_file =
      case Application.fetch_env(:quizline, :integrated_turn_cert_pkey) do
        {:ok, val} -> val
        :error -> nil
      end

    integrated_turn_options = [
      ip: turn_ip,
      mock_ip: turn_mock_ip,
      ports_range: Application.fetch_env!(:quizline, :integrated_turn_port_range),
      cert_file: turn_cert_file
    ]

    network_options = [
      integrated_turn_options: integrated_turn_options,
      integrated_turn_domain: Application.fetch_env!(:quizline, :integrated_turn_domain),
      dtls_pkey: Application.get_env(:quizline, :dtls_pkey),
      dtls_cert: Application.get_env(:quizline, :dtls_cert)
    ]

    tcp_turn_port = Application.get_env(:quizline, :integrated_tcp_turn_port)
    TURNManager.ensure_tcp_turn_launched(integrated_turn_options, port: tcp_turn_port)

    if turn_cert_file do
      tls_turn_port = Application.get_env(:quizline, :integrated_tls_turn_port)
      TURNManager.ensure_tls_turn_launched(integrated_turn_options, port: tls_turn_port)
    end

    {:ok, pid} = Membrane.RTC.Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())
    Process.monitor(pid)

    {:ok,
     %{
       rtc_engine: pid,
       peer_channels: %{},
       network_options: network_options,
       trace_ctx: trace_ctx,
       exam_status: :will_start,
       students: %{},
       invigilator: nil
     }}
  end

  @impl true
  def handle_info({:student, %{channel: channel, user: %{id: uid} = user}}, state) do
    Process.monitor(channel)

    state =
      state
      |> put_in([:peer_channels, uid], channel)
      |> put_in(
        [:students, uid],
        user |> Map.put(:time, DateTime.utc_now() |> DateTime.to_unix())
      )

    [{_pid, lv_pid}] = Registry.lookup(Quizline.SessionRegistry, uid)

    case state.invigilator do
      %{id: id} ->
        [{_pid, lv_pid}] = Registry.lookup(Quizline.SessionRegistry, id)
        send(lv_pid, {:current_students, state.students})

      _ ->
        nil
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:invigilator, %{channel: channel, user: %{id: uid} = user}}, state) do
    Process.monitor(channel)
    [{_pid, lv_pid}] = Registry.lookup(Quizline.SessionRegistry, uid)
    send(lv_pid, {:current_students, state.students})

    {:noreply,
     state
     |> put_in([:peer_channels, uid], channel)
     |> Map.put(:invigilator, user |> Map.put(:time, DateTime.utc_now() |> DateTime.to_unix()))}
  end

  @impl true
  def handle_info(%Message.MediaEvent{to: :broadcast, data: data}, state) do
    for {_peer_id, pid} <- state.peer_channels, do: send(pid, {:media_event, data})

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.MediaEvent{to: to, data: data}, state) do
    if state.peer_channels[to] != nil do
      send(state.peer_channels[to], {:media_event, data})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.NewPeer{rtc_engine: rtc_engine, peer: peer}, state) do
    Membrane.Logger.info("New peer: #{inspect(peer)}. Accepting.")
    peer_channel_pid = Map.get(state.peer_channels, peer.id)
    peer_node = node(peer_channel_pid)

    handshake_opts =
      if state.network_options[:dtls_pkey] &&
           state.network_options[:dtls_cert] do
        [
          client_mode: false,
          dtls_srtp: true,
          pkey: state.network_options[:dtls_pkey],
          cert: state.network_options[:dtls_cert]
        ]
      else
        [
          client_mode: false,
          dtls_srtp: true
        ]
      end

    endpoint = %WebRTC{
      rtc_engine: rtc_engine,
      ice_name: peer.id,
      owner: self(),
      integrated_turn_options: state.network_options[:integrated_turn_options],
      integrated_turn_domain: state.network_options[:integrated_turn_domain],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer.id],
      trace_context: state.trace_ctx,
      webrtc_extensions: [Mid, Rid, TWCC],
      rtcp_fir_interval: Membrane.Time.seconds(10),
      simulcast_config: %SimulcastConfig{enabled: true, default_encoding: fn _track -> "m" end}
    }

    Engine.accept_peer(rtc_engine, peer.id)
    :ok = Engine.add_endpoint(rtc_engine, endpoint, peer_id: peer.id, node: peer_node)

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.PeerLeft{peer: peer}, state) do
    Membrane.Logger.info("Peer #{inspect(peer.id)} left RTC Engine")
    {:noreply, state}
  end

  @impl true
  def handle_info({:media_event, _from, _event} = msg, state) do
    Engine.receive_media_event(state.rtc_engine, msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    if pid == state.rtc_engine do
      {:stop, :normal, state}
    else
      {peer_id, _peer_channel_id} =
        state.peer_channels
        |> Enum.find(fn {_peer_id, peer_channel_pid} -> peer_channel_pid == pid end)

      state = state |> Map.put(:students, state.students |> Map.delete(peer_id))

      if not is_nil(state.invigilator) and not (state.invigilator.id == peer_id) do
        [{_pid, lv_pid}] = Registry.lookup(Quizline.SessionRegistry, state.invigilator.id)
        send(lv_pid, {:current_students, state.students})
      end

      Engine.remove_peer(state.rtc_engine, peer_id)
      {_elem, state} = pop_in(state, [:peer_channels, peer_id])
      {:noreply, state}
    end
  end

  defp create_context(name) do
    metadata = [
      {:"library.language", :erlang},
      {:"library.name", :membrane_rtc_engine},
      {:"library.version", "server:#{Application.spec(:membrane_rtc_engine, :vsn)}"}
    ]

    root_span = Tracer.start_span(name)
    parent_ctx = Tracer.set_current_span(root_span)
    otel_ctx = OpenTelemetry.Ctx.attach(parent_ctx)
    OpenTelemetry.Span.set_attributes(root_span, metadata)
    OpenTelemetry.Span.end_span(root_span)
    OpenTelemetry.Ctx.attach(otel_ctx)

    otel_ctx
  end
end
