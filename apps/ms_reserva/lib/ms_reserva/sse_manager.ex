defmodule MsReserva.SSEManager do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{connections: %{}}, name: __MODULE__)
  end

  def add_connection(pid, client_ip) do
    GenServer.cast(__MODULE__, {:add_connection, pid, client_ip})
    IO.puts("Conexão SSE adicionada: #{inspect(pid)} - IP: #{client_ip}")
  end

  def broadcast_event(data) do
    GenServer.cast(__MODULE__, {:broadcast, data})
  end

  @impl true
  def init(state) do
    IO.puts("SSEManager iniciado")
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_connection, pid, client_ip}, state) do
    Process.monitor(pid)
    connections = Map.put(state.connections, pid, client_ip)
    IO.puts("Total de conexões SSE: #{map_size(connections)}")
    {:noreply, %{state | connections: connections}}
  end

  @impl true
  def handle_cast({:broadcast, data}, state) do
    active_connections =
      state.connections
      |> Enum.filter(fn {pid, ip} ->
        Process.alive?(pid) && !MsReserva.BlacklistAgent.is_blacklisted?(ip)
      end)
      |> Enum.into(%{})

    Enum.each(active_connections, fn {pid, ip} ->
      send(pid, {:sse_event, data})
      IO.puts("Evento enviado para: #{inspect(pid)} - IP: #{ip}")
    end)

    {:noreply, %{state | connections: active_connections}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    IO.puts("Conexão SSE encerrada: #{inspect(pid)}, motivo: #{inspect(reason)}")
    connections = Map.delete(state.connections, pid)
    {:noreply, %{state | connections: connections}}
  end
end
