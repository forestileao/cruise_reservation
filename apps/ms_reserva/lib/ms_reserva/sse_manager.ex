defmodule MsReserva.SSEManager do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{connections: []}, name: __MODULE__)
  end

  def add_connection(pid) do
    GenServer.cast(__MODULE__, {:add_connection, pid})
  end

  def broadcast_event(data) do
    GenServer.cast(__MODULE__, {:broadcast, data})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_connection, pid}, state) do
    Process.monitor(pid)
    {:noreply, %{state | connections: [pid | state.connections]}}
  end

  @impl true
  def handle_cast({:broadcast, data}, state) do
    Enum.each(state.connections, fn pid ->
      send(pid, {:sse_event, data})
    end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    connections = List.delete(state.connections, pid)
    {:noreply, %{state | connections: connections}}
  end

  @impl true
  def handle_info({:basic_consume_ok, _}, state), do: {:noreply, state}
end
