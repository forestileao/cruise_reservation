defmodule MsItinerarios do
  use GenServer
  use AMQP

  @exchange "cruzeiros"
  @queue_reserva_criada "reserva-criada"
  @queue_reserva_cancelada "reserva-cancelada"

  defstruct itinerarios: %{}, conexao: nil, canal: nil

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def consultar_disponiveis(destino, data_embarque, porto_embarque) do
    GenServer.call(__MODULE__, {:consultar_disponiveis, destino, data_embarque, porto_embarque})
  end

  def verificar_disponibilidade(cruzeiro_id, data_embarque, num_cabines) do
    GenServer.call(__MODULE__, {:verificar_disponibilidade, cruzeiro_id, data_embarque, num_cabines})
  end

  @impl true
  def init(state) do

    itinerarios = %{
      "c1" => %{
        id: "c1",
        destino: "Caribe",
        datas_disponiveis: %{
          "2025-05-10" => %{cabines_disponiveis: 100, cabines_reservadas: 0},
          "2025-06-15" => %{cabines_disponiveis: 100, cabines_reservadas: 0},
          "2025-07-20" => %{cabines_disponiveis: 100, cabines_reservadas: 0}
        },
        navio: "Estrela do Mar",
        porto_embarque: "Miami",
        porto_desembarque: "Miami",
        lugares_visitados: ["Jamaica", "Bahamas", "México"],
        noites: 7,
        valor_por_pessoa: 3500
      },
      "c2" => %{
        id: "c2",
        destino: "Mediterrâneo",
        datas_disponiveis: %{
          "2025-06-05" => %{cabines_disponiveis: 80, cabines_reservadas: 0},
          "2025-07-10" => %{cabines_disponiveis: 80, cabines_reservadas: 0},
          "2025-08-15" => %{cabines_disponiveis: 80, cabines_reservadas: 0}
        },
        navio: "Horizonte Azul",
        porto_embarque: "Barcelona",
        porto_desembarque: "Barcelona",
        lugares_visitados: ["Itália", "Grécia", "França"],
        noites: 10,
        valor_por_pessoa: 5200
      },
      "c3" => %{
        id: "c3",
        destino: "Alasca",
        datas_disponiveis: %{
          "2025-06-20" => %{cabines_disponiveis: 60, cabines_reservadas: 0},
          "2025-07-25" => %{cabines_disponiveis: 60, cabines_reservadas: 0},
          "2025-08-30" => %{cabines_disponiveis: 60, cabines_reservadas: 0}
        },
        navio: "Aventura Gelada",
        porto_embarque: "Vancouver",
        porto_desembarque: "Vancouver",
        lugares_visitados: ["Juneau", "Skagway", "Ketchikan"],
        noites: 7,
        valor_por_pessoa: 4300
      }
    }


    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)

    fila_unica = "itinerarios_fila_unica"

    AMQP.Exchange.declare(canal, @exchange, :direct)
    AMQP.Queue.declare(canal, fila_unica <> @queue_reserva_criada)
    AMQP.Queue.declare(canal, fila_unica <> @queue_reserva_cancelada)

    AMQP.Queue.bind(canal, fila_unica <> @queue_reserva_criada, @exchange, routing_key: @queue_reserva_criada)
    AMQP.Queue.bind(canal, fila_unica <>  @queue_reserva_cancelada, @exchange, routing_key: @queue_reserva_cancelada)

    AMQP.Basic.consume(canal, fila_unica <> @queue_reserva_criada, nil, no_ack: true)
    AMQP.Basic.consume(canal, fila_unica <> @queue_reserva_cancelada, nil, no_ack: true)

    {:ok, %{state | itinerarios: itinerarios, conexao: conexao, canal: canal}}
  end

  @impl true
  def handle_call({:consultar_disponiveis, destino, data_embarque, porto_embarque}, _from, state) do
    itinerarios_filtrados =
      state.itinerarios
      |> Enum.filter(fn {_id, itinerario} ->
        match_destino = is_nil(destino) or destino == "" or
                       String.downcase(itinerario.destino) =~ String.downcase(destino)

        match_porto = is_nil(porto_embarque) or porto_embarque == "" or
                     String.downcase(itinerario.porto_embarque) =~ String.downcase(porto_embarque)

        match_data = is_nil(data_embarque) or data_embarque == "" or
                    Map.has_key?(itinerario.datas_disponiveis, data_embarque)

        match_destino and match_porto and match_data
      end)
      |> Enum.map(fn {_id, itinerario} ->

        %{
          id: itinerario.id,
          destino: itinerario.destino,
          datas_disponiveis: Map.keys(itinerario.datas_disponiveis),
          navio: itinerario.navio,
          porto_embarque: itinerario.porto_embarque,
          porto_desembarque: itinerario.porto_desembarque,
          lugares_visitados: itinerario.lugares_visitados,
          noites: itinerario.noites,
          valor_por_pessoa: itinerario.valor_por_pessoa
        }
      end)

    {:reply, {:ok, itinerarios_filtrados}, state}
  end

  @impl true
  def handle_call({:verificar_disponibilidade, cruzeiro_id, data_embarque, num_cabines}, _from, state) do
    case Map.get(state.itinerarios, cruzeiro_id) do
      nil ->
        {:reply, {:erro, "Cruzeiro não encontrado"}, state}

      itinerario ->
        case Map.get(itinerario.datas_disponiveis, data_embarque) do
          nil ->
            {:reply, {:erro, "Data não disponível"}, state}

          data_info ->
            cabines_livres = data_info.cabines_disponiveis - data_info.cabines_reservadas
            if cabines_livres >= num_cabines do
              {:reply, {:ok, %{disponivel: true, cabines_livres: cabines_livres}}, state}
            else
              {:reply, {:erro, "Cabines insuficientes. Disponíveis: #{cabines_livres}"}, state}
            end
        end
    end
  end


  @impl true
  def handle_info({:basic_deliver, payload, %{routing_key: @queue_reserva_criada}}, state) do
    try do
      mensagem = JSON.decode!(payload)
      cruzeiro_id = mensagem["cruzeiro_id"]
      data_embarque = mensagem["data_embarque"]
      num_cabines = mensagem["num_cabines"]

      case Map.get(state.itinerarios, cruzeiro_id) do
        nil ->
          IO.puts("Reserva para cruzeiro desconhecido: #{cruzeiro_id}")
          {:noreply, state}

        itinerario ->
          case Map.get(itinerario.datas_disponiveis, data_embarque) do
            nil ->
              IO.puts("Reserva para data inexistente: #{data_embarque}")
              {:noreply, state}

            data_info ->

              nova_data_info = %{data_info | cabines_reservadas: data_info.cabines_reservadas + num_cabines}
              novas_datas = Map.put(itinerario.datas_disponiveis, data_embarque, nova_data_info)
              novo_itinerario = %{itinerario | datas_disponiveis: novas_datas}
              novos_itinerarios = Map.put(state.itinerarios, cruzeiro_id, novo_itinerario)

              IO.puts("Cabines atualizadas para #{cruzeiro_id} em #{data_embarque}: +#{num_cabines} reservadas")
              {:noreply, %{state | itinerarios: novos_itinerarios}}
          end
      end
    rescue
      e ->
        IO.puts("Erro ao processar reserva criada: #{inspect(e)}")
        {:noreply, state}
    end
  end


  @impl true
  def handle_info({:basic_deliver, payload, %{routing_key: @queue_reserva_cancelada}}, state) do
    try do
      mensagem = JSON.decode!(payload)
      cruzeiro_id = mensagem["cruzeiro_id"]
      data_embarque = mensagem["data_embarque"]
      num_cabines = mensagem["num_cabines"]

      case Map.get(state.itinerarios, cruzeiro_id) do
        nil ->
          IO.puts("Cancelamento para cruzeiro desconhecido: #{cruzeiro_id}")
          {:noreply, state}

        itinerario ->
          case Map.get(itinerario.datas_disponiveis, data_embarque) do
            nil ->
              IO.puts("Cancelamento para data inexistente: #{data_embarque}")
              {:noreply, state}

            data_info ->

              cabines_liberadas = max(0, data_info.cabines_reservadas - num_cabines)
              nova_data_info = %{data_info | cabines_reservadas: cabines_liberadas}
              novas_datas = Map.put(itinerario.datas_disponiveis, data_embarque, nova_data_info)
              novo_itinerario = %{itinerario | datas_disponiveis: novas_datas}
              novos_itinerarios = Map.put(state.itinerarios, cruzeiro_id, novo_itinerario)

              IO.puts("Cabines liberadas para #{cruzeiro_id} em #{data_embarque}: -#{num_cabines} reservadas")
              {:noreply, %{state | itinerarios: novos_itinerarios}}
          end
      end
    rescue
      e ->
        IO.puts("Erro ao processar reserva cancelada: #{inspect(e)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:basic_consume_ok, _}, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    if state.conexao, do: AMQP.Connection.close(state.conexao)
    :ok
  end
end
