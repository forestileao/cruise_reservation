defmodule MsReserva do
  use GenServer
  use AMQP

  @exchange "cruzeiros"
  @exchange_promocoes "promocoes"
  @queue_reserva_criada "reserva-criada"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_pagamento_recusado "pagamento-recusado"
  @queue_bilhete_gerado "bilhete-gerado"

  defstruct reservas: %{}, itinerarios: [], promocoes: %{}, conexao: nil, canal: nil, callbacks: %{}

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

  def cancelar_reserva(reserva_id) do
    GenServer.call(__MODULE__, {:cancelar_reserva, reserva_id})
  end

  def listar_reservas() do
    GenServer.call(__MODULE__, {:listar_reservas})
  end


  def listar_promocoes() do
    GenServer.call(__MODULE__, {:listar_promocoes})
  end

  @impl true
  def init(state) do

    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)


    AMQP.Exchange.declare(canal, @exchange, :direct)


    AMQP.Exchange.declare(canal, @exchange_promocoes, :direct)

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


    destinos = ["Caribe", "Mediterrâneo", "Alasca", "Brasil", "Ásia"]
    for destino <- destinos do
      fila_promocao = "promocoes-#{String.downcase(destino)}-reserva"
      routing_key = "promocoes-#{String.downcase(destino)}"

      AMQP.Queue.declare(canal, fila_promocao)
      AMQP.Queue.bind(canal, fila_promocao, @exchange_promocoes, routing_key: routing_key)
      AMQP.Basic.consume(canal, fila_promocao, nil, no_ack: true)
    end

    {:ok, %{state | conexao: conexao, canal: canal}}
  end

  @impl true
  def handle_call({:consultar_itinerarios, destino, data_embarque, porto_embarque}, _from, state) do
    case make_get_itinerarios_request(destino, data_embarque, porto_embarque) do
      {:ok, itinerarios} ->
        {:reply, {:ok, itinerarios}, state}

      {:error, _} ->
        {:reply, {:erro, "Erro ao consultar itinerários"}, state}
    end
  end

  defp make_get_itinerarios_request(destino, data_embarque, porto_embarque) do
    params = %{}
    params = if destino, do: Map.put(params, "destino", destino), else: params
    params = if data_embarque, do: Map.put(params, "data_embarque", data_embarque), else: params
    params = if porto_embarque, do: Map.put(params, "porto_embarque", porto_embarque), else: params

    query_string = URI.encode_query(params)
    "http://localhost:4002/itinerarios/disponiveis?#{query_string}"
    url = "http://localhost:4002/itinerarios/disponiveis?#{query_string}"

    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        response = JSON.decode!(body)
        {:ok, response["itinerarios"]}

      {:error, _} ->
        IO.puts("Erro ao consultar MS Itinerários")
        {:ok, []}
    end
  end

  @impl true
  def handle_call({:efetuar_reserva, cruzeiro_id, data_embarque, num_passageiros, num_cabines}, _from, state) do

    verificacao_payload = %{
      cruzeiro_id: cruzeiro_id,
      data_embarque: data_embarque,
      num_cabines: num_cabines
    }

    case HTTPoison.post("http://localhost:4002/itinerarios/verificar",
                       JSON.encode!(verificacao_payload),
                       [{"Content-Type", "application/json"}]) do
      {:ok, %{status_code: 200, body: body}} ->
        result = JSON.decode!(body)
        if result["disponivel"] do
          reserva_id = "res_#{:rand.uniform(10000)}"

          {:ok, itinerarios} = make_get_itinerarios_request(nil, data_embarque, nil)
          itinerario = Enum.find(itinerarios, fn i -> i["id"] == cruzeiro_id end)
          valor_total = if itinerario, do: itinerario["valor_por_pessoa"] * num_passageiros, else: 0

          nova_reserva = %{
            id: reserva_id,
            cruzeiro_id: cruzeiro_id,
            data_embarque: data_embarque,
            num_passageiros: num_passageiros,
            num_cabines: num_cabines,
            valor_total: valor_total,
            status: "pendente",
            data_criacao: DateTime.utc_now() |> DateTime.to_string(),
            bilhete: nil
          }


          pagamento_payload = %{
            reserva_id: reserva_id,
            valor_total: valor_total,
            dados_cliente: %{
              num_passageiros: num_passageiros,
              num_cabines: num_cabines
            }
          }

          case HTTPoison.post("http://localhost:4003/pagamento/solicitar",
                             JSON.encode!(pagamento_payload),
                             [{"Content-Type", "application/json"}]) do
            {:ok, %{status_code: 200, body: body}} ->
              pagamento_response = JSON.decode!(body)


              nova_reserva = Map.put(nova_reserva, :link_pagamento, pagamento_response["link_pagamento"])
              novas_reservas = Map.put(state.reservas, reserva_id, nova_reserva)


              mensagem = JSON.encode!(%{
                reserva_id: reserva_id,
                cruzeiro_id: cruzeiro_id,
                data_embarque: data_embarque,
                num_cabines: num_cabines,
                valor_total: valor_total,
                data_criacao: nova_reserva.data_criacao
              })

              AMQP.Basic.publish(state.canal, @exchange, @queue_reserva_criada, mensagem)

              {:reply, {:ok, nova_reserva}, %{state | reservas: novas_reservas}}

            {:error, _} ->

              link_fallback = "https://pagamento.cruzeiros.com/#{reserva_id}"
              nova_reserva = Map.put(nova_reserva, :link_pagamento, link_fallback)
              novas_reservas = Map.put(state.reservas, reserva_id, nova_reserva)

              {:reply, {:ok, nova_reserva}, %{state | reservas: novas_reservas}}
          end
        else
          {:reply, {:erro, "Cabines insuficientes"}, state}
        end

      {:ok, %{status_code: 400, body: body}} ->
        error = JSON.decode!(body)
        {:reply, {:erro, error["erro"]}, state}

      {:error, _} ->
        {:reply, {:erro, "Erro ao verificar disponibilidade"}, state}
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

  @impl true
  def handle_call({:listar_reservas}, _from, state) do
    reservas = state.reservas
    {:reply, {:ok, reservas}, state}
  end


  @impl true
  def handle_call({:listar_promocoes}, _from, state) do

    promocoes_ativas =
      state.promocoes
      |> Map.values()
      |> Enum.filter(fn promocao -> promocao.ativa end)

    {:reply, {:ok, promocoes_ativas}, state}
  end

  @impl true
  def handle_call({:cancelar_reserva, reserva_id}, _from, state) do
    case Map.get(state.reservas, reserva_id) do
      nil ->
        {:reply, {:erro, "Reserva não encontrada"}, state}

      reserva ->
        if reserva.status in ["pendente", "pagamento_aprovado", "bilhete_gerado"] do

          reserva_cancelada = %{reserva | status: "cancelada"}
          novas_reservas = Map.put(state.reservas, reserva_id, reserva_cancelada)


          mensagem = JSON.encode!(%{
            reserva_id: reserva_id,
            cruzeiro_id: reserva.cruzeiro_id,
            data_embarque: reserva.data_embarque,
            num_cabines: reserva.num_cabines,
            status: "cancelada",
            data_cancelamento: DateTime.utc_now() |> DateTime.to_string()
          })

          AMQP.Basic.publish(state.canal, @exchange, "reserva-cancelada", mensagem)

          {:reply, {:ok, reserva_cancelada}, %{state | reservas: novas_reservas}}
        else
          {:reply, {:erro, "Reserva não pode ser cancelada no status atual"}, state}
        end
    end
  end

  @impl true
  def handle_cast({:registrar_callback, reserva_id, callback}, state) do
    callbacks = Map.put(state.callbacks, reserva_id, callback)
    {:noreply, %{state | callbacks: callbacks}}
  end


  def handle_info({:basic_deliver, payload, %{routing_key: routing_key}}, state) when routing_key not in [@queue_pagamento_aprovado, @queue_pagamento_recusado, @queue_bilhete_gerado, @queue_reserva_criada] do
    try do
      promocao_data = JSON.decode!(payload)
      promocao = %{
        id: promocao_data["promocao_id"],
        destino: promocao_data["destino"],
        titulo: promocao_data["titulo"],
        descricao: promocao_data["descricao"],
        desconto: promocao_data["desconto"],
        validade: promocao_data["validade"],
        ativa: true,
        data_recebimento: DateTime.utc_now() |> DateTime.to_string()
      }

      novas_promocoes = Map.put(state.promocoes, promocao.id, promocao)
      event_data = %{
        tipo: "promocao",
        titulo: "Nova Promoção!",
        mensagem: "#{promocao.titulo} - #{promocao.desconto}% de desconto",
        promocao: promocao
      }

      MsReserva.SSEManager.broadcast_event(event_data)

      IO.puts("Promoção processada com sucesso: #{promocao.titulo}")
      IO.puts("=====================================")

      {:noreply, %{state | promocoes: novas_promocoes}}
    rescue
      e ->
        IO.puts("ERRO ao processar promoção: #{inspect(e)}")
        IO.puts("=====================================")
        {:noreply, state}
    end
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
