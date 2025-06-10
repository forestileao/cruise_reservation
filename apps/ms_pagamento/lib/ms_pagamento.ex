defmodule MsPagamento do
  use GenServer
  use AMQP


  @exchange "cruzeiros"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_pagamento_recusado "pagamento-recusado"

  defstruct pagamentos: %{}, conexao: nil, canal: nil


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @impl true
  def init(state) do

    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)


    AMQP.Exchange.declare(canal, @exchange, :direct)

    AMQP.Queue.declare(canal, @queue_pagamento_aprovado)
    AMQP.Queue.declare(canal, @queue_pagamento_recusado)


    {:ok, %{state | conexao: conexao, canal: canal}}
  end


  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, state}
  end

  def get_canal do
    GenServer.call(__MODULE__, :get_canal)
  end

  @impl true
  def handle_call(:get_canal, _from, state) do
    {:reply, state.canal, state}
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

  def solicitar_link_pagamento(reserva_id, valor_total, dados_cliente \\ %{}) do
    GenServer.call(__MODULE__, {:solicitar_link_pagamento, reserva_id, valor_total, dados_cliente})
  end

  @impl true
  def handle_call({:solicitar_link_pagamento, reserva_id, valor_total, dados_cliente}, _from, state) do
    # Gerar link de pagamento
    link_pagamento = "http://localhost:4010/pay/#{reserva_id}?valor=#{valor_total}"

    # Criar registro de pagamento pendente
    pagamento = %{
      id: "pag_#{:rand.uniform(10000)}",
      reserva_id: reserva_id,
      valor: valor_total,
      status: "pendente",
      link_pagamento: link_pagamento,
      dados_cliente: dados_cliente,
      data_criacao: DateTime.utc_now() |> DateTime.to_string()
    }

    novos_pagamentos = Map.put(state.pagamentos, reserva_id, pagamento)

    {:reply, {:ok, %{link_pagamento: link_pagamento, pagamento_id: pagamento.id}},
     %{state | pagamentos: novos_pagamentos}}
  end

  @impl true
  def terminate(_reason, state) do
    AMQP.Connection.close(state.conexao)
    :ok
  end
end
