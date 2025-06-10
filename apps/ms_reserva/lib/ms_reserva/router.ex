defmodule MsReserva.Router do
  use Plug.Router
  use AMQP

  plug CORSPlug,
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    headers: ["content-type", "authorization", "accept"],
    expose: ["content-type"],
    credentials: true

  plug :match
  plug :dispatch

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: JSON

  defp cors(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, authorization")
  end

  # Endpoint OPTIONS para CORS preflight
  options _ do
    send_resp(conn, 200, "")
  end

  # Rota para consultar itinerários disponíveis
  get "/itinerarios/disponiveis" do
    conn =  Plug.Conn.fetch_query_params(conn)
    params = conn.query_params

    # Chama a função que consulta itinerários disponíveis
    {:ok, itinerarios} = MsReserva.consultar_itinerarios(params["destino"], params["data_embarque"], params["porto_embarque"])
    # Retorna a resposta em JSON
    send_resp(conn, 200, JSON.encode!(%{itinerarios: itinerarios}))
  end

  post "/itinerarios/reserva" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    params = JSON.decode!(body)

    case MsReserva.efetuar_reserva(
      params["cruzeiro_id"],
      params["data_embarque"],
      params["num_passageiros"],
      params["num_cabines"]
    ) do
      {:ok, reserva} ->
        send_resp(conn, 201, JSON.encode!(%{reserva: reserva}))
      {:erro, msg} ->
        send_resp(conn, 400, JSON.encode!(%{erro: msg}))
    end
  end

  get "/reservas" do
    {:ok, reservas} = MsReserva.listar_reservas()

    # Retorna a resposta em JSON
    send_resp(conn, 200, JSON.encode!(%{reservas: reservas}))
  end


  get "/reservas/:id" do
    case MsReserva.obter_status_reserva(conn.path_params["id"]) do
      {:ok, reserva} ->
        send_resp(conn, 200, JSON.encode!(%{reserva: reserva}))
      {:erro, msg} ->
        send_resp(conn, 404, JSON.encode!(%{erro: msg}))
    end
  end

  post "/reservas/:id/cancelar" do
    reserva_id = conn.path_params["id"]

    case MsReserva.cancelar_reserva(reserva_id) do
      {:ok, reserva} ->
        send_resp(conn, 200, JSON.encode!(%{success: true, reserva: reserva}))
      {:erro, msg} ->
        send_resp(conn, 400, JSON.encode!(%{success: false, erro: msg}))
    end
  end

  get "/promocoes" do
    case MsReserva.listar_promocoes() do
      {:ok, promocoes} ->
        send_resp(conn, 200, JSON.encode!(%{promocoes: promocoes}))
      {:erro, msg} ->
        send_resp(conn, 500, JSON.encode!(%{erro: msg}))
    end
  end

  get "/notificacoes/status" do
    send_resp(conn, 200, JSON.encode!(%{ativo: true}))
  end

  post "/notificacoes/registrar" do
    send_resp(conn, 200, JSON.encode!(%{success: true, mensagem: "Notificações ativadas"}))
  end

  post "/notificacoes/cancelar" do
    send_resp(conn, 200, JSON.encode!(%{success: true, mensagem: "Notificações canceladas"}))
  end

  get "/sse/promocoes" do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    # registrar conexão SSE
    MsReserva.SSEManager.add_connection(self())

    maintain_sse_connection(conn)
  end

  defp maintain_sse_connection(conn) do
    receive do
      {:sse_event, data} ->
        case chunk(conn, "data: #{JSON.encode!(data)}\n\n") do
          {:ok, conn} -> maintain_sse_connection(conn)
          {:error, _} -> :ok
        end
      :close ->
        :ok
    after
      30_000 ->
        case chunk(conn, "data: #{JSON.encode!(%{type: "heartbeat"})}\n\n") do
          {:ok, conn} -> maintain_sse_connection(conn)
          {:error, _} -> :ok
        end
    end
  end

  # Rota para lidar com caminhos não encontrados
  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
