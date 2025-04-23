defmodule MsReserva do
  use GenServer
  use AMQP


  @exchange "cruzeiros"
  @queue_reserva_criada "reserva-criada"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_pagamento_recusado "pagamento-recusado"
  @queue_bilhete_gerado "bilhete-gerado"


  defstruct reservas: %{}, itinerarios: [], conexao: nil, canal: nil, callbacks: %{}


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def consultar_itinerarios(destino, data_embarque, porto_embarque) do
    GenServer.call(__MODULE__, {:consultar_itinerarios, destino, data_embarque, porto_embarque})
  end

  def efetuar_reserva(cruzeiro_id, data_embarque, num_passageiros, num_cabines) do
    GenServer.call(__MODULE__, {:efetuar_reserva, cruzeiro_id, data_embarque, num_passageiros, num_cabines})
  end

  def obter_status_reserva(reserva_id) do
    GenServer.call(__MODULE__, {:obter_status_reserva, reserva_id})
  end

  def registrar_callback(reserva_id, callback) do
    GenServer.cast(__MODULE__, {:registrar_callback, reserva_id, callback})
  end


  @impl true
  def init(state) do

    itinerarios = [
      %{
        id: "c1",
        destino: "Caribe",
        datas_disponiveis: ["2025-05-10", "2025-06-15", "2025-07-20"],
        navio: "Estrela do Mar",
        porto_embarque: "Miami",
        porto_desembarque: "Miami",
        lugares_visitados: ["Jamaica", "Bahamas", "México"],
        noites: 7,
        valor_por_pessoa: 3500
      },
      %{
        id: "c2",
        destino: "Mediterrâneo",
        datas_disponiveis: ["2025-06-05", "2025-07-10", "2025-08-15"],
        navio: "Horizonte Azul",
        porto_embarque: "Barcelona",
        porto_desembarque: "Barcelona",
        lugares_visitados: ["Itália", "Grécia", "França"],
        noites: 10,
        valor_por_pessoa: 5200
      },
      %{
        id: "c3",
        destino: "Alasca",
        datas_disponiveis: ["2025-06-20", "2025-07-25", "2025-08-30"],
        navio: "Aventura Gelada",
        porto_embarque: "Vancouver",
        porto_desembarque: "Vancouver",
        lugares_visitados: ["Juneau", "Skagway", "Ketchikan"],
        noites: 7,
        valor_por_pessoa: 4300
      }
    ]


    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)


    AMQP.Exchange.declare(canal, @exchange, :direct)

    AMQP.Queue.declare(canal, @queue_reserva_criada)
    AMQP.Queue.declare(canal, @queue_pagamento_aprovado <> "_ms_reserva")
    AMQP.Queue.declare(canal, @queue_pagamento_recusado)
    AMQP.Queue.declare(canal, @queue_bilhete_gerado)


    AMQP.Queue.bind(canal, @queue_pagamento_aprovado <> "_ms_reserva", @exchange, routing_key: @queue_pagamento_aprovado)
    AMQP.Queue.bind(canal, @queue_pagamento_recusado, @exchange, routing_key: @queue_pagamento_recusado)
    AMQP.Queue.bind(canal, @queue_bilhete_gerado, @exchange, routing_key: @queue_bilhete_gerado)


    AMQP.Basic.consume(canal, @queue_pagamento_aprovado <> "_ms_reserva", nil, no_ack: true)
    AMQP.Basic.consume(canal, @queue_pagamento_recusado, nil, no_ack: true)
    AMQP.Basic.consume(canal, @queue_bilhete_gerado, nil, no_ack: true)

    {:ok, %{state | itinerarios: itinerarios, conexao: conexao, canal: canal}}
  end

  @impl true
  def handle_call({:consultar_itinerarios, destino, data_embarque, porto_embarque}, _from, state) do

    itinerarios_filtrados = state.itinerarios
    |> Enum.filter(fn itinerario ->
      (destino == nil || String.downcase(itinerario.destino) =~ String.downcase(destino)) &&
      (data_embarque == nil || Enum.member?(itinerario.datas_disponiveis, data_embarque)) &&
      (porto_embarque == nil || String.downcase(itinerario.porto_embarque) =~ String.downcase(porto_embarque))
    end)

    {:reply, {:ok, itinerarios_filtrados}, state}
  end

  @impl true
  def handle_call({:efetuar_reserva, cruzeiro_id, data_embarque, num_passageiros, num_cabines}, _from, state) do

    case Enum.find(state.itinerarios, fn i -> i.id == cruzeiro_id end) do
      nil ->
        {:reply, {:erro, "Cruzeiro não encontrado"}, state}

      itinerario ->

        reserva_id = "res_#{:rand.uniform(10000)}"
        valor_total = itinerario.valor_por_pessoa * num_passageiros

        nova_reserva = %{
          id: reserva_id,
          cruzeiro_id: cruzeiro_id,
          data_embarque: data_embarque,
          num_passageiros: num_passageiros,
          num_cabines: num_cabines,
          valor_total: valor_total,
          status: "pendente",
          link_pagamento: "https://pagamento.cruzeiros.com/#{reserva_id}",
          data_criacao: DateTime.utc_now() |> DateTime.to_string(),
          bilhete: nil
        }


        novas_reservas = Map.put(state.reservas, reserva_id, nova_reserva)


        mensagem = JSON.encode!(%{
          reserva_id: reserva_id,
          valor_total: valor_total,
          data_criacao: nova_reserva.data_criacao
        })

        AMQP.Basic.publish(state.canal, @exchange, @queue_reserva_criada, mensagem)

        {:reply, {:ok, nova_reserva}, %{state | reservas: novas_reservas}}
    end
  end

  @impl true
  def handle_call({:obter_status_reserva, reserva_id}, _from, state) do
    case Map.get(state.reservas, reserva_id) do
      nil ->
        {:reply, {:erro, "Reserva não encontrada"}, state}

      reserva ->
        {:reply, {:ok, reserva}, state}
    end
  end

  def listar_reservas() do
    GenServer.call(__MODULE__, {:listar_reservas})
  end

  @impl true
  def handle_call({:listar_reservas}, _from, state) do
    reservas = state.reservas
    {:reply, {:ok, reservas}, state}
  end

  @impl true
  def handle_cast({:registrar_callback, reserva_id, callback}, state) do
    callbacks = Map.put(state.callbacks, reserva_id, callback)
    {:noreply, %{state | callbacks: callbacks}}
  end


  def handle_info({:basic_deliver, payload, %{routing_key: @queue_pagamento_aprovado}}, state) do
    payload = JSON.decode!(payload)
    IO.puts("Mensagem de pagamento aprovado: #{inspect(payload)}")


    if verificar_assinatura(payload) do
      mensagem = payload["mensagem"]
      reserva_id = mensagem["reserva_id"]

      case Map.get(state.reservas, reserva_id) do
        nil ->
          IO.puts("Pagamento aprovado para reserva desconhecida: #{reserva_id}")

        reserva ->

          reserva_atualizada = %{reserva | status: "pagamento_aprovado"}
          novas_reservas = Map.put(state.reservas, reserva_id, reserva_atualizada)


          case Map.get(state.callbacks, reserva_id) do
            nil -> :ok
            callback -> callback.("pagamento_aprovado")
          end

          {:noreply, %{state | reservas: novas_reservas}}
      end
    else
      IO.puts("Assinatura inválida em mensagem de pagamento aprovado")
      {:noreply, state}
    end

  end

  def handle_info({:basic_deliver, payload, %{routing_key: @queue_pagamento_recusado}}, state) do
    payload = JSON.decode!(payload)

    if verificar_assinatura(payload) do
      mensagem = payload["mensagem"]

      reserva_id = mensagem["reserva_id"]

      case Map.get(state.reservas, reserva_id) do
        nil ->
          IO.puts("Pagamento recusado para reserva desconhecida: #{reserva_id}")

        reserva ->

          reserva_atualizada = %{reserva | status: "cancelada"}
          novas_reservas = Map.put(state.reservas, reserva_id, reserva_atualizada)


          case Map.get(state.callbacks, reserva_id) do
            nil -> :ok
            callback -> callback.("pagamento_recusado")
          end

          {:noreply, %{state | reservas: novas_reservas}}
      end
    else
      IO.puts("Assinatura inválida em mensagem de pagamento recusado")
      {:noreply, state}
    end
  end

  def handle_info({:basic_deliver, payload, %{routing_key: @queue_bilhete_gerado}}, state) do
    IO.puts("Recebendo mensagem de bilhete gerado")
    mensagem = JSON.decode!(payload)
    reserva_id = mensagem["reserva_id"]
    bilhete_info = mensagem["bilhete"]

    case Map.get(state.reservas, reserva_id) do
      nil ->
        IO.puts("Bilhete gerado para reserva desconhecida: #{reserva_id}")
        {:noreply, state}


      reserva ->

        reserva_atualizada = %{reserva | status: "bilhete_gerado", bilhete: bilhete_info}

        novas_reservas = Map.put(state.reservas, reserva_id, reserva_atualizada)


        case Map.get(state.callbacks, reserva_id) do
          nil -> :ok
          callback -> callback.("bilhete_gerado")
        end

        {:noreply, %{state | reservas: novas_reservas}}
    end
  end

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

  @impl true
  def terminate(_reason, state) do

    AMQP.Connection.close(state.conexao)
    :ok
  end
end
