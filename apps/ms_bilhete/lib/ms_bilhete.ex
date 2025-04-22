defmodule MsBilhete do
  use GenServer
  use AMQP

  # Definições das filas
  @exchange "cruzeiros"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_bilhete_gerado "bilhete-gerado"

  # Chave pública do MS Pagamento (simulada para o exemplo)
  @pagamento_public_key "pagamento_public_key_simulada"

  # Estado inicial do GenServer
  defstruct bilhetes: %{}, conexao: nil, canal: nil

  # API pública
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def obter_bilhete(reserva_id) do
    GenServer.call(__MODULE__, {:obter_bilhete, reserva_id})
  end

  # Callbacks do GenServer
  @impl true
  def init(state) do
    # Conectar ao RabbitMQ e configurar canais
    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)

    # Declarar exchange e filas
    AMQP.Exchange.declare(canal, @exchange, :direct)

    AMQP.Queue.declare(canal, @queue_pagamento_aprovado)
    AMQP.Queue.declare(canal, @queue_bilhete_gerado)

    # Binding para filas que este MS escuta
    AMQP.Queue.bind(canal, @queue_pagamento_aprovado, @exchange, routing_key: @queue_pagamento_aprovado)

    # Configurar consumidor
    AMQP.Basic.consume(canal, @queue_pagamento_aprovado, nil, no_ack: true)

    {:ok, %{state | conexao: conexao, canal: canal}}
  end

  @impl true
  def handle_call({:obter_bilhete, reserva_id}, _from, state) do
    case Map.get(state.bilhetes, reserva_id) do
      nil ->
        {:reply, {:erro, "Bilhete não encontrado"}, state}

      bilhete ->
        {:reply, {:ok, bilhete}, state}
    end
  end

  @impl true
  def handle_info({:basic_deliver, payload, %{routing_key: @queue_pagamento_aprovado}}, state) do
    mensagem = Jason.decode!(payload)

    # Verificar assinatura digital
    if verificar_assinatura(mensagem, @pagamento_public_key) do
      reserva_id = mensagem["reserva_id"]
      pagamento_id = mensagem["pagamento_id"]

      # Gerar um novo bilhete
      bilhete = %{
        id: "bil_#{:rand.uniform(10000)}",
        reserva_id: reserva_id,
        pagamento_id: pagamento_id,
        codigo_verificacao: gerar_codigo_verificacao(),
        data_emissao: DateTime.utc_now() |> DateTime.to_string(),
        status: "emitido"
      }

      # Adicionar bilhete ao estado
      novos_bilhetes = Map.put(state.bilhetes, reserva_id, bilhete)

      # Publicar mensagem na fila de bilhetes gerados
      mensagem_bilhete = %{
        "reserva_id" => reserva_id,
        "bilhete" => %{
          "id" => bilhete.id,
          "codigo_verificacao" => bilhete.codigo_verificacao,
          "data_emissao" => bilhete.data_emissao
        }
      }

      AMQP.Basic.publish(state.canal, @exchange, @queue_bilhete_gerado, Jason.encode!(mensagem_bilhete))

      IO.puts("Bilhete gerado para reserva #{reserva_id}: #{bilhete.codigo_verificacao}")

      {:noreply, %{state | bilhetes: novos_bilhetes}}
    else
      IO.puts("Assinatura inválida em mensagem de pagamento aprovado")
      {:noreply, state}
    end
  end

  # Função helper para simular verificação de assinatura digital
  defp verificar_assinatura(mensagem, chave_publica) do
    # Simulação de verificação de assinatura
    # Em um ambiente real, isso usaria criptografia de chave pública
    assinatura = mensagem["assinatura"]
    true # Simulando sucesso na verificação
  end

  # Função helper para gerar código de verificação do bilhete
  defp gerar_codigo_verificacao do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end

  @impl true
  def terminate(_reason, state) do
    # Fechar conexão com RabbitMQ
    AMQP.Connection.close(state.conexao)
    :ok
  end
end
