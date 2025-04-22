defmodule MsReserva do
  use GenServer
  use AMQP

  # Definições das filas
  @exchange "cruzeiros"
  @queue_reserva_criada "reserva-criada"
  @queue_pagamento_aprovado "pagamento-aprovado"
  @queue_pagamento_recusado "pagamento-recusado"
  @queue_bilhete_gerado "bilhete-gerado"

  # Chave pública do MS Pagamento (simulada para o exemplo)
  @pagamento_public_key "pagamento_public_key_simulada"

  # Estado inicial do GenServer
  defstruct reservas: %{}, itinerarios: [], conexao: nil, canal: nil, callbacks: %{}

  # API pública
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

  # Callbacks do GenServer
  @impl true
  def init(state) do
    # Inicializa os itinerários disponíveis
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

    # Conectar ao RabbitMQ e configurar canais
    {:ok, conexao} = AMQP.Connection.open()
    {:ok, canal} = AMQP.Channel.open(conexao)

    # Declarar exchange e filas
    AMQP.Exchange.declare(canal, @exchange, :direct)

    AMQP.Queue.declare(canal, @queue_reserva_criada)
    AMQP.Queue.declare(canal, @queue_pagamento_aprovado)
    AMQP.Queue.declare(canal, @queue_pagamento_recusado)
    AMQP.Queue.declare(canal, @queue_bilhete_gerado)

    # Binding para filas que este MS escuta
    AMQP.Queue.bind(canal, @queue_pagamento_aprovado, @exchange, routing_key: @queue_pagamento_aprovado)
    AMQP.Queue.bind(canal, @queue_pagamento_recusado, @exchange, routing_key: @queue_pagamento_recusado)
    AMQP.Queue.bind(canal, @queue_bilhete_gerado, @exchange, routing_key: @queue_bilhete_gerado)

    # Configurar consumidores
    AMQP.Basic.consume(canal, @queue_pagamento_aprovado, nil, no_ack: true)
    AMQP.Basic.consume(canal, @queue_pagamento_recusado, nil, no_ack: true)
    AMQP.Basic.consume(canal, @queue_bilhete_gerado, nil, no_ack: true)

    {:ok, %{state | itinerarios: itinerarios, conexao: conexao, canal: canal}}
  end

  @impl true
  def handle_call({:consultar_itinerarios, destino, data_embarque, porto_embarque}, _from, state) do
    # Filtrar itinerários com base nos parâmetros fornecidos
    itinerarios_filtrados = state.itinerarios
    |> Enum.filter(fn itinerario ->
      (destino == nil || itinerario.destino == destino) &&
      (data_embarque == nil || Enum.member?(itinerario.datas_disponiveis, data_embarque)) &&
      (porto_embarque == nil || itinerario.porto_embarque == porto_embarque)
    end)

    {:reply, {:ok, itinerarios_filtrados}, state}
  end

  @impl true
  def handle_call({:efetuar_reserva, cruzeiro_id, data_embarque, num_passageiros, num_cabines}, _from, state) do
    # Verificar se o cruzeiro existe
    case Enum.find(state.itinerarios, fn i -> i.id == cruzeiro_id end) do
      nil ->
        {:reply, {:erro, "Cruzeiro não encontrado"}, state}

      itinerario ->
        # Criar nova reserva
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
          data_criacao: DateTime.utc_now() |> DateTime.to_string()
        }

        # Adicionar reserva ao estado
        novas_reservas = Map.put(state.reservas, reserva_id, nova_reserva)

        # Publicar mensagem na fila de reservas criadas
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

  @impl true
  def handle_cast({:registrar_callback, reserva_id, callback}, state) do
    callbacks = Map.put(state.callbacks, reserva_id, callback)
    {:noreply, %{state | callbacks: callbacks}}
  end

  # Handlers para mensagens AMQP
  def handle_info({:basic_deliver, payload, %{routing_key: @queue_pagamento_aprovado}}, state) do
    mensagem = JSON.decode!(payload)

    # Verificar assinatura digital (simulado)
    if verificar_assinatura(mensagem, @pagamento_public_key) do
      reserva_id = mensagem["reserva_id"]

      case Map.get(state.reservas, reserva_id) do
        nil ->
          IO.puts("Pagamento aprovado para reserva desconhecida: #{reserva_id}")

        reserva ->
          # Atualizar status da reserva
          reserva_atualizada = %{reserva | status: "pagamento_aprovado"}
          novas_reservas = Map.put(state.reservas, reserva_id, reserva_atualizada)

          # Notificar via callback se houver
          case Map.get(state.callbacks, reserva_id) do
            nil -> :ok
            callback -> callback.("pagamento_aprovado")
          end

          {:noreply, %{state | reservas: novas_reservas}}
      end
    else
      IO.puts("Assinatura inválida em mensagem de pagamento aprovado")
    end

    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, %{routing_key: @queue_pagamento_recusado}}, state) do
    mensagem = JSON.decode!(payload)

    # Verificar assinatura digital (simulado)
    if verificar_assinatura(mensagem, @pagamento_public_key) do
      reserva_id = mensagem["reserva_id"]

      case Map.get(state.reservas, reserva_id) do
        nil ->
          IO.puts("Pagamento recusado para reserva desconhecida: #{reserva_id}")

        reserva ->
          # Atualizar status da reserva para cancelada
          reserva_atualizada = %{reserva | status: "cancelada"}
          novas_reservas = Map.put(state.reservas, reserva_id, reserva_atualizada)

          # Notificar via callback se houver
          case Map.get(state.callbacks, reserva_id) do
            nil -> :ok
            callback -> callback.("pagamento_recusado")
          end

          {:noreply, %{state | reservas: novas_reservas}}
      end
    else
      IO.puts("Assinatura inválida em mensagem de pagamento recusado")
    end

    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, %{routing_key: @queue_bilhete_gerado}}, state) do
    mensagem = JSON.decode!(payload)
    reserva_id = mensagem["reserva_id"]
    bilhete_info = mensagem["bilhete"]

    case Map.get(state.reservas, reserva_id) do
      nil ->
        IO.puts("Bilhete gerado para reserva desconhecida: #{reserva_id}")

      reserva ->
        # Atualizar status da reserva e adicionar informações do bilhete
        reserva_atualizada = %{reserva | status: "bilhete_gerado", bilhete: bilhete_info}
        novas_reservas = Map.put(state.reservas, reserva_id, reserva_atualizada)

        # Notificar via callback se houver
        case Map.get(state.callbacks, reserva_id) do
          nil -> :ok
          callback -> callback.("bilhete_gerado")
        end

        {:noreply, %{state | reservas: novas_reservas}}
    end

    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, state}
  end

  # Função helper para simular verificação de assinatura digital
  defp verificar_assinatura(mensagem, chave_publica) do
    # Simulação de verificação de assinatura
    # Em um ambiente real, isso usaria criptografia de chave pública
    assinatura = mensagem["assinatura"]
    true # Simulando sucesso na verificação
  end

  @impl true
  def terminate(_reason, state) do
    # Fechar conexão com RabbitMQ
    AMQP.Connection.close(state.conexao)
    :ok
  end
end
