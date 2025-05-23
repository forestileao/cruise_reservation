defmodule FrontWeb.ReservaLive.Index do
  use Phoenix.LiveView
  use AMQP

  def mount(_params, _session, socket) do
    # Simulando que temos algumas reservas do usuário
    reservas = get_reservas()

    {:ok, assign(socket, page_title: "Minhas Reservas", reservas: reservas)}
  end

  def get_reservas do
    {:ok, response} = Tesla.get(client(), "/reservas")
    {:ok, reservas} = JSON.decode(response.body)
    reservas
    |> Map.get("reservas")
    |> Enum.map(fn {id, reserva} ->
      %{
        id: id,
        cruzeiro_id: reserva["cruzeiro_id"],
        data_criacao: reserva["data_criacao"],
        status: reserva["status"],
        valor_total: reserva["valor_total"]
      }
    end)
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
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold text-blue-700">Minhas Reservas</h1>
        <a href="/reservas/nova" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
          Nova Reserva
        </a>
      </div>

      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <table class="min-w-full">
          <thead class="bg-gray-100">
            <tr>
              <th class="py-3 px-4 text-left">ID</th>
              <th class="py-3 px-4 text-left">Cruzeiro</th>
              <th class="py-3 px-4 text-left">Data</th>
              <th class="py-3 px-4 text-left">Valor Total</th>
              <th class="py-3 px-4 text-left">Status</th>
              <th class="py-3 px-4 text-left"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <%= for reserva <- @reservas do %>
              <tr class="hover:bg-gray-50">
                <td class="py-3 px-4"><%=  Map.get(reserva, :id, "N/A" ) %></td>
                <td class="py-3 px-4"><%= Map.get(reserva, :cruzeiro_id, "N/A" ) %></td>
                <td class="py-3 px-4"><%= Map.get(reserva, :data_criacao, "N/A" ) %></td>
                <td class="py-3 px-4"><%= Map.get(reserva, :valor_total, "N/A" ) %></td>
                <td class="py-3 px-4">
                  <%= case reserva.status do %>
                    <% "pendente" -> %>
                      <span class="px-2 py-1 text-xs rounded-full bg-yellow-100 text-yellow-800">Aguardando Pagamento</span>
                    <% "pagamento_aprovado" -> %>
                      <span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">Pagamento Aprovado</span>
                    <% "bilhete_gerado" -> %>
                      <span class="px-2 py-1 text-xs rounded-full bg-green-100 text-green-800">Bilhete Emitido</span>
                    <% "cancelada" -> %>
                      <span class="px-2 py-1 text-xs rounded-full bg-red-100 text-red-800">Cancelada</span>
                    <% _ -> %>
                      <span class="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800"><%= reserva.status %></span>
                  <% end %>
                </td>
                <td class="py-3 px-4">
                  <a href={"/reservas/#{reserva.id}"} class="text-blue-600 hover:text-blue-800">Detalhes</a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
