defmodule MsSubscriber do
  use GenServer
  use AMQP

  @exchange_promocoes "promocoes"
  @destinos ["Caribe", "Mediterrâneo", "Alasca", "Brasil", "Ásia"]

  defstruct [:connection, :channel, :destinos_inscritos]

  def start_link(opts \\ []) do
    destinos = Keyword.get(opts, :destinos, @destinos)
    GenServer.start_link(__MODULE__, %__MODULE__{destinos_inscritos: destinos}, name: __MODULE__)
  end

  def inscrever_destino(destino) do
    GenServer.cast(__MODULE__, {:inscrever_destino, destino})
  end

  def cancelar_inscricao(destino) do
    GenServer.cast(__MODULE__, {:cancelar_inscricao, destino})
  end

  def listar_destinos_inscritos do
    GenServer.call(__MODULE__, :listar_destinos_inscritos)
  end

  @impl true
  def init(state) do
    # Estabelecer conexão com RabbitMQ
    case AMQP.Connection.open() do
      {:ok, connection} ->
        Process.monitor(connection.pid)
        case AMQP.Channel.open(connection) do
          {:ok, channel} ->
            # Declarar exchange
            AMQP.Exchange.declare(channel, @exchange_promocoes, :direct)

            # Inscrever-se em todos os destinos iniciais
            state = %{state | connection: connection, channel: channel}

            Enum.each(state.destinos_inscritos, fn destino ->
              inscrever_em_fila(destino, state)
            end)

            {:ok, state}

          {:error, reason} ->
            {:stop, {:channel_open_failed, reason}}
        end

      {:error, reason} ->
        {:stop, {:connection_failed, reason}}
    end
  end

  @impl true
  def handle_cast({:inscrever_destino, destino}, state) do
    if destino in @destinos and destino not in state.destinos_inscritos do
      inscrever_em_fila(destino, state)
      {:noreply, %{state | destinos_inscritos: [destino | state.destinos_inscritos]}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:cancelar_inscricao, destino}, state) do
    if destino in state.destinos_inscritos do
      cancelar_inscricao_fila(destino, state)
      {:noreply, %{state | destinos_inscritos: List.delete(state.destinos_inscritos, destino)}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:listar_destinos_inscritos, _from, state) do
    {:reply, state.destinos_inscritos, state}
  end

  # Manipular mensagens recebidas do RabbitMQ
  @impl true
  def handle_info({:basic_deliver, payload, %{routing_key: routing_key}}, state) do
    try do
      promocao = JSON.decode!(payload)
      IO.puts("\n===== NOVA PROMOÇÃO RECEBIDA =====")
      IO.puts("Destino: #{promocao["destino"]}")
      IO.puts("Título: #{promocao["titulo"]}")
      IO.puts("Descrição: #{promocao["descricao"]}")
      IO.puts("Desconto: #{promocao["desconto"]}%")
      IO.puts("Validade: #{promocao["validade"]}")
      IO.puts("ID da Promoção: #{promocao["promocao_id"]}")
      IO.puts("Canal: #{routing_key}")
      IO.puts("=====================================\n")
    rescue
      e -> IO.puts("Erro ao processar mensagem: #{inspect(e)}")
    end

    {:noreply, state}
  end

  # Confirmações de consumo
  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Cancelamentos de consumo
  @impl true
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  # Conexão caiu
  @impl true
  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    {:stop, {:connection_lost, reason}, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.connection do
      AMQP.Connection.close(state.connection)
    end
    :ok
  end

  # Funções privadas auxiliares
  defp inscrever_em_fila(destino, state) do
    fila = "promocoes-#{String.downcase(destino)}"

    # Declarar a fila
    AMQP.Queue.declare(state.channel, fila)

    # Vincular a fila ao exchange
    AMQP.Queue.bind(state.channel, fila, @exchange_promocoes, routing_key: fila)

    # Iniciar consumo
    {:ok, _consumer_tag} = AMQP.Basic.consume(state.channel, fila, nil, no_ack: true)

    IO.puts("Inscrito para receber promoções de #{destino}")
  end

  defp cancelar_inscricao_fila(destino, state) do
    fila = "promocoes-#{String.downcase(destino)}"

    # Desvincular a fila do exchange
    AMQP.Queue.unbind(state.channel, fila, @exchange_promocoes, routing_key: fila)

    IO.puts("Cancelada inscrição para promoções de #{destino}")
  end
end
