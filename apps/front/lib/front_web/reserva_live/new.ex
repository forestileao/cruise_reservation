defmodule FrontWeb.ReservaLive.New do
  use Phoenix.LiveView
  alias Front.Client  # Supondo que você tenha um client Tesla para chamar os serviços
  import JSON, only: [decode!: 1]
  require Logger

  def mount(_params, _session, socket) do
    socket = assign(socket,
      page_title: "Nova Reserva",
      destino: "",
      data_embarque: "",
      porto_embarque: "",
      itinerarios: [],
      cruzeiro_selecionado: nil,
      num_passageiros: 1,
      num_cabines: 1,
      reserva: nil,
      step: 1
    )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <h1 class="text-3xl font-bold text-blue-700 mb-4"><%= @page_title %></h1>
        <div>
          <%= if @step == 1 do %>
            <div class="mb-6">
              <h2 class="text-xl font-bold mb-4">Passo 1: Filtros de Itinerário</h2>
              <form phx-submit="buscar_cruzeiros" >
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <input type="text" name="destino" value={@destino} placeholder="Destino" class="p-2 border rounded w-full"/>
                  <input type="date" name="data_embarque" value={@data_embarque} class="p-2 border rounded w-full"/>
                  <input type="text" name="porto_embarque" value={@porto_embarque} placeholder="Porto de Embarque" class="p-2 border rounded w-full"/>
                </div>
                <div class="mt-4">
                  <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Buscar Itinerários</button>
                </div>
              </form>
            </div>
          <% end %>
          <%= if @step == 2 do %>
            <div class="mb-6">
              <h2 class="text-xl font-bold mb-4">Passo 2: Selecionar Itinerário</h2>
              <div class="grid grid-cols-1 gap-6">
                <%= for itin <- @itinerarios do %>
                  <div class="border p-4 rounded shadow">
                    <h3 class="text-xl font-semibold text-blue-800"><%= itin["destino"] %> - <%= itin["navio"] %></h3>
                    <p><strong>Datas disponíveis:</strong> <%= Enum.join(itin["datas_disponiveis"], ", ") %></p>
                    <p><strong>Porto de Embarque:</strong> <%= itin["porto_embarque"] %></p>
                    <p><strong>Porto de Desembarque:</strong> <%= itin["porto_desembarque"] %></p>
                    <p><strong>Lugares Visitados:</strong> <%= Enum.join(itin["lugares_visitados"], ", ") %></p>
                    <p><strong>Noites:</strong> <%= itin["noites"] %> noites</p>
                    <p><strong>Valor por Pessoa:</strong> R$ <%= itin["valor_por_pessoa"] %></p>
                    <button phx-click="selecionar_cruzeiro" phx-value-id={itin["id"]} class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded mt-2">Selecionar Cruzeiro</button>
                  </div>
                <% end %>
              </div>
              <div class="mt-4">
                <button phx-click="voltar_step" class="bg-gray-600 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded">Voltar</button>
              </div>
            </div>
          <% end %>
          <%= if @step == 3 do %>
            <div class="mb-6">
              <h2 class="text-xl font-bold mb-4">Passo 3: Detalhes da Reserva</h2>
              <form phx-submit="finalizar_reserva" method="post">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block font-semibold">Número de Passageiros</label>
                    <input type="number" name="num_passageiros" value={@num_passageiros} class="p-2 border rounded w-full" min="1" />
                  </div>
                  <div>
                    <label class="block font-semibold">Número de Cabines</label>
                    <input type="number" name="num_cabines" value={@num_cabines} class="p-2 border rounded w-full" min="1" />
                  </div>
                </div>
                <div class="mt-4">
                  <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Finalizar Reserva</button>
                </div>
              </form>
              <div class="mt-4">
                <button phx-click="voltar_step" class="bg-gray-600 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded">Voltar</button>
              </div>
            </div>
          <% end %>
          <%= if @step == 4 do %>
            <div class="mb-6">
              <h2 class="text-xl font-bold mb-4">Passo 4: Reserva Concluída</h2>
              <div class="p-4 bg-green-100 border border-green-500 rounded">
                <p class="text-green-700 font-bold">Sua reserva foi realizada com sucesso!</p>
                <p><strong>Link de pagamento:</strong> <a href={@reserva["link_pagamento"]} class="text-blue-600">Clique aqui para pagar</a></p>
                <p><strong>ID da Reserva:</strong> <%= @reserva["id"] %></p>
                <p><strong>Status:</strong> <%= @reserva["status"] %></p>
                <p><strong>Data de Criação:</strong> <%= @reserva["data_criacao"] %></p>
              </div>
              <div class="mt-4">
                <button phx-click="voltar_step" class="bg-gray-600 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded">Voltar</button>
                <a href="/" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Home</a>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("buscar_cruzeiros", %{
        "destino" => destino,
        "data_embarque" => data_embarque,
        "porto_embarque" => porto_embarque
      }, socket) do

    query = Enum.filter([
      destino && destino != "" && {:destino, destino},
      data_embarque && data_embarque != "" && {:data_embarque, data_embarque},
      porto_embarque && porto_embarque != "" && {:porto_embarque, porto_embarque}
    ], & &1)

    Logger.debug("Query: #{inspect(query)}")
    itinerarios =
      case Tesla.get(client(), "/itinerarios/disponiveis", query: query) do
        {:ok, %{body: json}} ->
          decode!(json) |> Map.get("itinerarios") # retorna lista de itinerários

        _ ->
          []
      end

    {:noreply,
     assign(socket,
       destino: destino,
       data_embarque: data_embarque,
       porto_embarque: porto_embarque,
       itinerarios: itinerarios,
       step: 2
     )}
  end

  def handle_event("alterar_destino", %{"destino" => destino}, socket) do
    {:noreply, assign(socket, destino: destino)}
  end

  def handle_event("selecionar_cruzeiro", %{"id" => id}, socket) do
    {:noreply, assign(socket, cruzeiro_selecionado: id, step: 3)}
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

  def handle_event("finalizar_reserva", %{
        "num_passageiros" => passageiros,
        "num_cabines" => cabines
      }, socket) do

    payload = %{
      "cruzeiro_id" => socket.assigns.cruzeiro_selecionado,
      "data_embarque" => socket.assigns.data_embarque,
      "num_passageiros" => String.to_integer(passageiros),
      "num_cabines" => String.to_integer(cabines)
    }

    reserva =
      case Tesla.post(client(), "/itinerarios/reserva", payload) do
        {:ok, %{body: json}} ->
          Logger.debug("Reserva JSON: #{inspect(json)}")
          decode!(json)
          |> Map.get("reserva")

          _ ->
          nil
      end

    {:noreply, assign(socket,
      reserva: reserva,
      step: 4
    )}
  end


  def client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "http://localhost:4001"},
      Tesla.Middleware.JSON
    ])
  end
end
