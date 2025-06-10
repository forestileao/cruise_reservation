defmodule SimuladorPagamentoExterno do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def simular_processamento_pagamento(reserva_id, valor) do
    GenServer.cast(__MODULE__, {:processar_pagamento, reserva_id, valor})
  end

  @impl true
  def init(state) do
    IO.puts("Simulador Externo de Pagamento iniciado")
    {:ok, state}
  end

  @impl true
  def handle_cast({:processar_pagamento, reserva_id, valor}, state) do
    Task.start(fn ->

      status = if :rand.uniform(100) <= 80, do: "aprovado", else: "recusado"

      webhook_payload = %{
        transaction_id: "txn_#{:rand.uniform(10000)}",
        reserva_id: reserva_id,
        status: status,
        valor: valor,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        gateway: "SimulatedGateway"
      }

      enviar_webhook(webhook_payload)
    end)

    {:noreply, state}
  end

  defp enviar_webhook(payload) do
    webhook_url = "http://localhost:4003/webhook/pagamento"

    case HTTPoison.post(webhook_url, JSON.encode!(payload), [{"Content-Type", "application/json"}]) do
      {:ok, %{status_code: 200}} ->
        IO.puts("Webhook enviado com sucesso: #{payload.status} para reserva #{payload.reserva_id}")

      {:error, reason} ->
        IO.puts("Erro ao enviar webhook: #{inspect(reason)}")
    end
  end
end
