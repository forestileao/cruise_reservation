defmodule FrontWeb.HomeLive do
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  alias Phoenix.LiveView.Socket

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:destino, nil)
     |> assign(:data_embarque, nil)
     |> assign(:porto_embarque, nil)
     |> assign(:itinerarios, [])}
  end

  def handle_params(params, _uri, socket) do
    destino = Map.get(params, "destino")
    data_embarque = Map.get(params, "data_embarque")
    porto_embarque = Map.get(params, "porto_embarque")

    query =
      Enum.filter([
        destino && destino != "" && {:destino, destino},
        data_embarque && data_embarque != "" && {:data_embarque, data_embarque},
        porto_embarque && porto_embarque != "" && {:porto_embarque, porto_embarque}
      ], & &1)


    itinerarios =
      case Tesla.get(client(), "/itinerarios/disponiveis", query: query) do
        {:ok, %{body: json}} -> JSON.decode!(json) |> Map.get("itinerarios", [])
        {:error, reason} ->
          IO.inspect(reason, label: "Error fetching itineraries")
          []
        _ -> []
      end

    {:noreply,
     socket
     |> assign(:destino, destino)
     |> assign(:data_embarque, data_embarque)
     |> assign(:porto_embarque, porto_embarque)
     |> assign(:itinerarios, itinerarios)}
  end

  def handle_event("filter", params, socket) do
    IO.inspect(params, label: "FILTER PARAMS")

    destino = Map.get(params, "destino")
    data_embarque = Map.get(params, "data_embarque")
    porto_embarque = Map.get(params, "porto_embarque")

    query =
      Enum.filter([
        destino && destino != "" && {:destino, destino},
        data_embarque && data_embarque != "" && {:data_embarque, data_embarque},
        porto_embarque && porto_embarque != "" && {:porto_embarque, porto_embarque}
      ], & &1)

    IO.inspect(query, label: "QUERY PARAMS")

    itinerarios =
      case Tesla.get(client(), "/itinerarios/disponiveis", query: query) do
        {:ok, %{body: json}} ->
          IO.inspect(json, label: "RESPONSE JSON")
          JSON.decode!(json) |> Map.get("itinerarios", [])

        {:error, reason} ->
          IO.inspect(reason, label: "API ERROR")
          []
      end

    {:noreply,
     socket
     |> assign(:destino, destino)
     |> assign(:data_embarque, data_embarque)
     |> assign(:porto_embarque, porto_embarque)
     |> assign(:itinerarios, itinerarios)}
  end



  def client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "http://localhost:4001"},
      Tesla.Middleware.JSON
    ])
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <h1 class="text-3xl font-bold text-blue-700 mb-4">Bem-vindo ao CruzeiroMar</h1>
        <p class="text-gray-700 mb-4">
          Descubra o mundo navegando em nossos luxuosos cruzeiros. Oferecemos destinos incríveis,
          acomodações confortáveis e experiências inesquecíveis.
        </p>

        <div class="mt-6 flex space-x-4">
          <a href="/reservas" class="bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded">Minhas Reservas</a>
          <a href="/reservas/nova" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Fazer uma Reserva</a>
          <a href="/assinante" class="bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded">Assinar Promoções</a>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <h2 class="text-xl font-bold mb-4">Filtrar Itinerários</h2>
        <form phx-change="filter">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <input type="text" name="destino" value={@destino} placeholder="Destino" class="p-2 border rounded w-full"/>
          <input type="date" name="data_embarque" value={@data_embarque} class="p-2 border rounded w-full"/>
          <input type="text" name="porto_embarque" value={@porto_embarque} placeholder="Porto de Embarque" class="p-2 border rounded w-full"/>
        </div>
        <div class="mt-4">
          <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Buscar</button>
          <a href="/" class="ml-4 text-blue-500 underline">Limpar / Atualizar</a>
        </div>
      </form>

      </div>

      <div class="bg-white rounded-lg shadow-md p-6">
        <h2 class="text-2xl font-bold text-blue-700 mb-4">Itinerários Disponíveis</h2>
        <%= if @itinerarios == [] do %>
          <p class="text-gray-500">Nenhum itinerário encontrado com os filtros fornecidos.</p>
        <% else %>
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
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
