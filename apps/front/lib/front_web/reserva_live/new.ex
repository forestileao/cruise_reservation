defmodule FrontWeb.ReservaLive.New do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    destinos = ["", "Caribe", "Mediterrâneo", "Alasca"]
    portos = ["", "Miami", "Barcelona", "Vancouver"]

    socket = assign(socket,
      page_title: "Nova Reserva",
      destino: "",
      data_embarque: "",
      porto_embarque: "",
      itinerarios: [],
      cruzeiro_selecionado: nil,
      step: 1,
      num_passageiros: 2,
      num_cabines: 1,
      reserva: nil
    )

    {:ok, socket}
  end

  def render(assigns) do
  end

  def handle_event("buscar_cruzeiros", %{"destino" => destino, "data_embarque" => data_embarque, "porto_embarque" => porto_embarque}, socket) do
    # Aqui seria a chamada para o MS Reserva
    # Simulando recebimento de dados
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

    # Filtrar por critérios, se fornecidos
    filtered_itinerarios = itinerarios
    |> Enum.filter(fn i ->
      (destino == "" || i.destino == destino) &&
      (porto_embarque == "" || i.porto_embarque == porto_embarque)
    end)

    {:noreply, assign(socket,
      destino: destino,
      data_embarque: data_embarque,
      porto_embarque: porto_embarque,
      itinerarios: filtered_itinerarios,
      step: 2
    )}
  end

  def handle_event("alterar_destino", %{"destino" => destino}, socket) do
    {:noreply, assign(socket, destino: destino)}
  end

  def handle_event("selecionar_cruzeiro", %{"id" => id}, socket) do
    {:noreply, assign(socket, cruzeiro_selecionado: id)}
  end

  def handle_event("voltar_step", _, socket) do
    {:noreply, assign(socket, step: socket.assigns.step - 1)}
  end

  def handle_event("avancar_step", _, socket) do
    {:noreply, assign(socket, step: socket.assigns.step + 1)}
  end

  def handle_event("alterar_passageiros", %{"num_passageiros" => passageiros}, socket) do
    {:noreply, assign(socket, num_passageiros: String.to_integer(passageiros))}
  end

  def handle_event("finalizar_reserva", %{"num_passageiros" => passageiros, "num_cabines" => cabines}, socket) do
    # Aqui seria a chamada para o MS Reserva para efetuar a reserva
    # Simulando resposta
    reserva = %{
      id: "res_#{:rand.uniform(10000)}",
      cruzeiro_id: socket.assigns.cruzeiro_selecionado,
      data_embarque: socket.assigns.data_embarque,
      num_passageiros: String.to_integer(passageiros),
      num_cabines: String.to_integer(cabines),
      status: "pendente",
      link_pagamento: "https://pagamento.cruzeiros.com/reserva123",
      data_criacao: DateTime.utc_now() |> DateTime.to_string()
    }

    {:noreply, assign(socket, reserva: reserva, step: 4)}
  end
end
