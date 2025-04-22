defmodule FrontWeb.ReservaLive.Show do
  use Phoenix.LiveView
  import JSON, only: [decode!: 1]
  require Logger

  def mount(%{"id" => reserva_id}, _session, socket) do
    # Buscando os detalhes da reserva usando o ID
    reserva = get_reserva(reserva_id)

    # Atribuindo ao socket a reserva e o estado inicial
    {:ok, assign(socket, reserva: reserva)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <h1 class="text-3xl font-bold text-blue-700 mb-4">Detalhes da Reserva</h1>

        <%= if @reserva do %>
          <div class="p-4 bg-green-100 border border-green-500 rounded">
            <p><strong>ID da Reserva:</strong> <%= @reserva["id"] %></p>
            <p><strong>Status:</strong> <%= @reserva["status"] %></p>
            <p><strong>Data de Criação:</strong> <%= @reserva["data_criacao"] %></p>
            <p><strong>Link de pagamento:</strong> <a href={@reserva["link_pagamento"]} class="text-blue-600">Clique aqui para pagar</a></p>
            <p><strong>Numero de Passageiros:</strong> <%= @reserva["num_passageiros"] %></p>
            <p><strong>Numero de Cabines:</strong> <%= @reserva["num_cabines"] %></p>
            <p><strong>Cruzeiro:</strong> <%= @reserva["cruzeiro_id"] %></p>
            <p><strong>Valor total:</strong> <%= @reserva["valor_total"] %></p>
          </div>
          <div class="p-4 bg-green-100 border border-green-500 rounded mt-4">

          <pre>
          Bilhete: <%= Jason.encode!(@reserva["bilhete"], pretty: true) %>
          </pre>
          </div>
        <% else %>
          <p>Reserva não encontrada.</p>
        <% end %>
      </div>
    </div>
    """
  end

  # Função para buscar os detalhes da reserva
  defp get_reserva(reserva_id) do
    case Tesla.get(client(), "/reservas/#{reserva_id}") do
      {:ok, %{body: json}} ->
        decode!(json)
        |> Map.get("reserva")

      {:error, reason} ->
        Logger.error("Erro ao buscar reserva: #{inspect(reason)}")
        nil
    end
  end

  def client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "http://localhost:4001"},
      Tesla.Middleware.JSON
    ])
  end
end
