# Novo módulo para gerenciar conexões SSE - VERSÃO CORRIGIDA
defmodule MsReserva.SSEManager do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{connections: []}, name: __MODULE__)
  end

  def add_connection(pid) do
    GenServer.cast(__MODULE__, {:add_connection, pid})
    IO.puts("Conexão SSE adicionada: #{inspect(pid)}")
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
  def handle_cast({:add_connection, pid}, state) do
    # Monitorar processo da conexão
    Process.monitor(pid)
    connections = [pid | state.connections]
    {:noreply, %{state | connections: connections}}
  end

  @impl true
  def handle_cast({:broadcast, data}, state) do

    # Enviar para todas as conexões SSE ativas
    active_connections = Enum.filter(state.connections, fn pid ->
      Process.alive?(pid)
    end)

    Enum.each(active_connections, fn pid ->
      send(pid, {:sse_event, data})
      IO.puts("Evento enviado para: #{inspect(pid)}")
    end)

    # Atualizar lista apenas com conexões vivas
    {:noreply, %{state | connections: active_connections}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    IO.puts("Conexão SSE encerrada: #{inspect(pid)}, motivo: #{inspect(reason)}")
    # Remover conexão que foi fechada
    connections = List.delete(state.connections, pid)
    {:noreply, %{state | connections: connections}}
  end

  @impl true
  def handle_info({:basic_consume_ok, _}, state), do: {:noreply, state}
end
