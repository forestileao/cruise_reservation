defmodule MsPagamento do
  use GenServer
  use AMQP


  @exchange "cruzeiros"
  @queue_reserva_criada "reserva-criada"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_pagamento_recusado "pagamento-recusado"


  @private_key "pagamento_private_key_simulada"

  defstruct pagamentos: %{}, conexao: nil, canal: nil


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @impl true
  def init(state) do

    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)


    AMQP.Exchange.declare(canal, @exchange, :direct)

    AMQP.Queue.declare(canal, @queue_reserva_criada)
    AMQP.Queue.declare(canal, @queue_pagamento_aprovado)
    AMQP.Queue.declare(canal, @queue_pagamento_recusado)


    AMQP.Queue.bind(canal, @queue_reserva_criada, @exchange, routing_key: @queue_reserva_criada)


    AMQP.Basic.consume(canal, @queue_reserva_criada, nil, no_ack: true)

    {:ok, %{state | conexao: conexao, canal: canal}}
  end



  @impl true


  def handle_info({:basic_deliver, payload, %{routing_key: @queue_reserva_criada}}, state) do
    mensagem = JSON.decode!(payload)
    reserva_id = mensagem["reserva_id"]
    valor_total = mensagem["valor_total"]


    pagamento_aprovado = :rand.uniform(100) > 50


    pagamento = %{
      id: "pag_#{:rand.uniform(10000)}",
      reserva_id: reserva_id,
      valor: valor_total,
      status: if(pagamento_aprovado, do: "aprovado", else: "recusado"),
      data_processamento: DateTime.utc_now() |> DateTime.to_string()
    }


    novos_pagamentos = Map.put(state.pagamentos, reserva_id, pagamento)


    mensagem_base = %{
      "reserva_id" => reserva_id,
      "pagamento_id" => pagamento.id,
      "valor" => valor_total,
      "status" => pagamento.status,
      "data_processamento" => pagamento.data_processamento
    }

    assinatura = assinar_mensagem(mensagem_base |> JSON.encode!())
    payload = %{
      "mensagem" => mensagem_base,
      "assinatura" => assinatura
    }

    fila_destino = if pagamento_aprovado, do: @queue_pagamento_aprovado, else: @queue_pagamento_recusado
    AMQP.Basic.publish(state.canal, @exchange, fila_destino, JSON.encode!(payload))

    IO.puts("Pagamento #{pagamento.status} para reserva #{reserva_id}, valor: #{valor_total}")

    {:noreply, %{state | pagamentos: novos_pagamentos}}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, state}
  end

  def assinar_mensagem(mensagem) do
    private_key =
      Application.get_env(:ms_pagamento, :private_key)
      |> :public_key.pem_decode()
      |> hd()
      |> :public_key.pem_entry_decode()

    :public_key.sign(mensagem, :sha256, private_key)
    |> Base.encode64()
  end

  @impl true
  def terminate(_reason, state) do
    AMQP.Connection.close(state.conexao)
    :ok
  end
end
