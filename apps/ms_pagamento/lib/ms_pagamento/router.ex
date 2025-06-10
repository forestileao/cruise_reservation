defmodule MsPagamento.Router do
  use Plug.Router

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: JSON

  plug :cors
  plug :match
  plug :dispatch

  defp cors(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type")
  end

  options _ do
    send_resp(conn, 200, "")
  end

  # API para solicitar link de pagamento
  post "/pagamento/solicitar" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    params = JSON.decode!(body)

    case MsPagamento.solicitar_link_pagamento(
      params["reserva_id"],
      params["valor_total"],
      params["dados_cliente"] || %{}
    ) do
      {:ok, result} ->
        send_resp(conn, 200, JSON.encode!(result))
      {:erro, msg} ->
        send_resp(conn, 400, JSON.encode!(%{erro: msg}))
    end
  end

  post "/webhook/pagamento" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    try do
      evento = JSON.decode!(body)
      IO.puts("Webhook recebido: #{inspect(evento)}")

      reserva_id = evento["reserva_id"]
      status = evento["status"]

      mensagem_base = %{
        "reserva_id" => reserva_id,
        "pagamento_id" => evento["transaction_id"],
        "valor" => evento["valor"],
        "status" => status,
        "data_processamento" => evento["timestamp"]
      }

      assinatura = MsPagamento.assinar_mensagem(mensagem_base |> JSON.encode!())

      payload = %{
        "mensagem" => mensagem_base,
        "assinatura" => assinatura
      }

      # Publicar na fila apropriada baseado no status
      fila_destino = case status do
        "aprovado" -> "pagamento-aprovado"
        "recusado" -> "pagamento-recusado"
        _ -> nil
      end

      if fila_destino do
        # Obter canal do GenServer
        canal = GenServer.call(MsPagamento, :get_canal)
        AMQP.Basic.publish(canal, "cruzeiros", fila_destino, JSON.encode!(payload))
        IO.puts("Evento #{status} publicado para reserva #{reserva_id}")
      end

      send_resp(conn, 200, JSON.encode!(%{status: "processado"}))
    rescue
      e ->
        IO.puts("Erro ao processar webhook: #{inspect(e)}")
        send_resp(conn, 400, JSON.encode!(%{erro: "Webhook inválido"}))
    end
  end
end
