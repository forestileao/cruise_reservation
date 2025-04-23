defmodule MsBilhete do
  use GenServer
  use AMQP


  @exchange "cruzeiros"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_bilhete_gerado "bilhete-gerado"


  defstruct bilhetes: %{}, conexao: nil, canal: nil


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def obter_bilhete(reserva_id) do
    GenServer.call(__MODULE__, {:obter_bilhete, reserva_id})
  end


  @impl true
  def init(state) do

    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)


    AMQP.Exchange.declare(canal, @exchange, :direct)

    AMQP.Queue.declare(canal, @queue_pagamento_aprovado)
    AMQP.Queue.declare(canal, @queue_bilhete_gerado)


    AMQP.Queue.bind(canal, @queue_pagamento_aprovado, @exchange, routing_key: @queue_pagamento_aprovado)


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
    payload = JSON.decode!(payload)
    IO.puts("Mensagem de pagamento aprovado: #{inspect(payload)}")


    if verificar_assinatura(payload) do
      mensagem = payload["mensagem"]
      reserva_id = mensagem["reserva_id"]
      pagamento_id = mensagem["pagamento_id"]


      bilhete = %{
        id: "bil_#{:rand.uniform(10000)}",
        reserva_id: reserva_id,
        pagamento_id: pagamento_id,
        codigo_verificacao: gerar_codigo_verificacao(),
        data_emissao: DateTime.utc_now() |> DateTime.to_string(),
        status: "emitido"
      }


      novos_bilhetes = Map.put(state.bilhetes, reserva_id, bilhete)


      mensagem_bilhete = %{
        "reserva_id" => reserva_id,
        "bilhete" => %{
          "id" => bilhete.id,
          "codigo_verificacao" => bilhete.codigo_verificacao,
          "data_emissao" => bilhete.data_emissao
        }
      }

      AMQP.Basic.publish(state.canal, @exchange, @queue_bilhete_gerado, JSON.encode!(mensagem_bilhete))

      IO.puts("Bilhete gerado para reserva #{reserva_id}: #{bilhete.codigo_verificacao}")

      {:noreply, %{state | bilhetes: novos_bilhetes}}
    else
      IO.puts("Assinatura inválida em mensagem de pagamento aprovado")
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, state}
  end


  def verificar_assinatura(payload) do
    public_key = Application.get_env(:ms_reserva, :public_key)
      |> :public_key.pem_decode()
      |> hd()
      |> :public_key.pem_entry_decode()
    assinatura = payload["assinatura"] |> Base.decode64!()
    mensagem = payload["mensagem"] |> JSON.encode!()

    :public_key.verify(mensagem, :sha256, assinatura, public_key)
  end


  defp gerar_codigo_verificacao do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end

  @impl true
  def terminate(_reason, state) do

    AMQP.Connection.close(state.conexao)
    :ok
  end
end
