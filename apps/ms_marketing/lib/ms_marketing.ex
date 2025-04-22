defmodule MsMarketing do
  use GenServer
  use AMQP


  @exchange "cruzeiros"
  @exchange_promocoes "promocoes"


  @destinos ["Caribe", "Mediterrâneo", "Alasca", "Brasil", "Ásia"]


  defstruct promocoes: %{}, conexao: nil, canal: nil


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def publicar_promocao(destino, titulo, descricao, desconto, validade) do
    GenServer.cast(__MODULE__, {:publicar_promocao, destino, titulo, descricao, desconto, validade})
  end

  def listar_promocoes_ativas do
    GenServer.call(__MODULE__, :listar_promocoes_ativas)
  end


  @impl true
  def init(state) do

    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)


    AMQP.Exchange.declare(canal, @exchange, :direct)
    AMQP.Exchange.declare(canal, @exchange_promocoes, :direct)


    for destino <- @destinos do
      nome_fila = "promocoes-#{String.downcase(destino)}"
      AMQP.Queue.declare(canal, nome_fila)
      AMQP.Queue.bind(canal, nome_fila, @exchange_promocoes, routing_key: nome_fila)
    end


    promocoes_iniciais = %{
      "promo_1" => %{
        id: "promo_1",
        destino: "Caribe",
        titulo: "Verão no Caribe com 20% de desconto",
        descricao: "Aproveite o verão no Caribe com 20% de desconto em todos os cruzeiros.",
        desconto: 20,
        validade: "2025-12-31",
        ativa: true
      },
      "promo_2" => %{
        id: "promo_2",
        destino: "Mediterrâneo",
        titulo: "Visite a Europa com 15% de desconto",
        descricao: "Conheça o melhor do Mediterrâneo com 15% de desconto em cruzeiros selecionados.",
        desconto: 15,
        validade: "2025-10-31",
        ativa: true
      }
    }

    estado_atualizado = %{state | promocoes: promocoes_iniciais, conexao: conexao, canal: canal}


    for {_, promocao} <- promocoes_iniciais do
      publicar_promocao_em_fila(promocao, estado_atualizado)
    end


    Process.send_after(self(), :publicar_promocao_aleatoria, 20_000)

    {:ok, estado_atualizado}
  end

  @impl true
  def handle_cast({:publicar_promocao, destino, titulo, descricao, desconto, validade}, state) do
    promocao_id = "promo_#{:rand.uniform(10000)}"

    nova_promocao = %{
      id: promocao_id,
      destino: destino,
      titulo: titulo,
      descricao: descricao,
      desconto: desconto,
      validade: validade,
      ativa: true,
      data_criacao: DateTime.utc_now() |> DateTime.to_string()
    }


    novas_promocoes = Map.put(state.promocoes, promocao_id, nova_promocao)
    estado_atualizado = %{state | promocoes: novas_promocoes}


    publicar_promocao_em_fila(nova_promocao, estado_atualizado)

    {:noreply, estado_atualizado}
  end

  @impl true
  def handle_call(:listar_promocoes_ativas, _from, state) do

    promocoes_ativas =
      state.promocoes
      |> Enum.filter(fn {_, promocao} -> promocao.ativa end)
      |> Enum.map(fn {_, promocao} -> promocao end)

    {:reply, promocoes_ativas, state}
  end


  @impl true
  def handle_info(:publicar_promocao_aleatoria, state) do

    destino = Enum.random(@destinos)


    desconto = Enum.random(10..30)
    validade = Date.utc_today() |> Date.add(Enum.random(30..90)) |> Date.to_string()

    promocao_id = "promo_#{:rand.uniform(10000)}"
    nova_promocao = %{
      id: promocao_id,
      destino: destino,
      titulo: "Oferta relâmpago: #{desconto}% off para #{destino}",
      descricao: "Aproveite esta oferta por tempo limitado. #{desconto}% de desconto em cruzeiros para #{destino}.",
      desconto: desconto,
      validade: validade,
      ativa: true,
      data_criacao: DateTime.utc_now() |> DateTime.to_string()
    }


    novas_promocoes = Map.put(state.promocoes, promocao_id, nova_promocao)
    estado_atualizado = %{state | promocoes: novas_promocoes}


    publicar_promocao_em_fila(nova_promocao, estado_atualizado)

    IO.puts("Promoção aleatória publicada: #{nova_promocao.titulo}")


    Process.send_after(self(), :publicar_promocao_aleatoria, 30_000)

    {:noreply, estado_atualizado}
  end


  defp publicar_promocao_em_fila(promocao, state) do
    fila_destino = "promocoes-#{String.downcase(promocao.destino)}"

    mensagem = %{
      "promocao_id" => promocao.id,
      "destino" => promocao.destino,
      "titulo" => promocao.titulo,
      "descricao" => promocao.descricao,
      "desconto" => promocao.desconto,
      "validade" => promocao.validade
    }

    AMQP.Basic.publish(state.canal, @exchange_promocoes, fila_destino, JSON.encode!(mensagem))
    IO.puts("Promoção publicada para #{promocao.destino}: #{promocao.titulo}")
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do

    AMQP.Connection.close(state.conexao)
    :ok
  end
end
