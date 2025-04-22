defmodule MsPagamento do
  use GenServer
  use AMQP

  # Definições das filas
  @exchange "cruzeiros"
  @queue_reserva_criada "reserva-criada"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_pagamento_recusado "pagamento-recusado"

  # Chaves para assinatura digital (simuladas para o exemplo)
  @private_key "pagamento_private_key_simulada"
  @public_key "pagamento_public_key_simulada"

  # Estado inicial do GenServer
  defstruct pagamentos: %{}, conexao: nil, canal: nil

  # API pública
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def get_public_key do
    @public_key
  end

  # Callbacks do GenServer
  @impl true
  def init(state) do
    # Conectar ao RabbitMQ e configurar canais
    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)

    # Declarar exchange e filas
    AMQP.Exchange.declare(canal, @exchange, :direct)

    AMQP.Queue.declare(canal, @queue_reserva_criada)
    AMQP.Queue.declare(canal, @queue_pagamento_aprovado)
    AMQP.Queue.declare(canal, @queue_pagamento_recusado)

    # Binding para filas que este MS escuta
    AMQP.Queue.bind(canal, @queue_reserva_criada, @exchange, routing_key: @queue_reserva_criada)

    # Configurar consumidor
    AMQP.Basic.consume(canal, @queue_reserva_criada, nil, no_ack: true)

    {:ok, %{state | conexao: conexao, canal: canal}}
  end



  @impl true

  # Handlers para mensagens AMQP
  def handle_info({:basic_deliver, payload, %{routing_key: @queue_reserva_criada}}, state) do
    mensagem = JSON.decode!(payload)
    reserva_id = mensagem["reserva_id"]
    valor_total = mensagem["valor_total"]

    # Simular processamento de pagamento (aprovação aleatória)
    pagamento_aprovado = :rand.uniform(100) > 20  # 80% de chance de aprovação

    # Criar registro de pagamento
    pagamento = %{
      id: "pag_#{:rand.uniform(10000)}",
      reserva_id: reserva_id,
      valor: valor_total,
      status: if(pagamento_aprovado, do: "aprovado", else: "recusado"),
      data_processamento: DateTime.utc_now() |> DateTime.to_string()
    }

    # Adicionar pagamento ao estado
    novos_pagamentos = Map.put(state.pagamentos, reserva_id, pagamento)

    # Preparar mensagem com assinatura digital
    mensagem_base = %{
      "reserva_id" => reserva_id,
      "pagamento_id" => pagamento.id,
      "valor" => valor_total,
      "status" => pagamento.status,
      "data_processamento" => pagamento.data_processamento
    }

    mensagem_assinada = Map.put(mensagem_base, "assinatura", assinar_mensagem(mensagem_base, @private_key))

    fila_destino = if pagamento_aprovado, do: @queue_pagamento_aprovado, else: @queue_pagamento_recusado
    AMQP.Basic.publish(state.canal, @exchange, fila_destino, JSON.encode!(mensagem_assinada))

    IO.puts("Pagamento #{pagamento.status} para reserva #{reserva_id}, valor: #{valor_total}")

    {:noreply, %{state | pagamentos: novos_pagamentos}}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, state}
  end

  defp assinar_mensagem(mensagem, chave_privada) do
    "assinatura_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
  end

  @impl true
  def terminate(_reason, state) do
    AMQP.Connection.close(state.conexao)
    :ok
  end
end
