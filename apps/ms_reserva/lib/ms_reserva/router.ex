defmodule MsReserva.Router do
  use Plug.Router
  use AMQP

  # ORDEM CORRETA DOS PLUGS - CORS deve vir ANTES de match/dispatch
  plug CORSPlug,
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]


  plug :match
  plug :dispatch

  # Rota para consultar itinerários disponíveis
  get "/itinerarios/disponiveis" do
    conn = Plug.Conn.fetch_query_params(conn)
    params = conn.query_params

    # Chama a função que consulta itinerários disponíveis
    {:ok, itinerarios} = MsReserva.consultar_itinerarios(params["destino"], params["data_embarque"], params["porto_embarque"])

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{itinerarios: itinerarios}))
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
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(201, JSON.encode!(%{reserva: reserva}))
      {:erro, msg} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, JSON.encode!(%{erro: msg}))
    end
  end

  get "/reservas" do
    {:ok, reservas} = MsReserva.listar_reservas()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{reservas: reservas}))
  end

  get "/reservas/:id" do
    case MsReserva.obter_status_reserva(conn.path_params["id"]) do
      {:ok, reserva} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, JSON.encode!(%{reserva: reserva}))
      {:erro, msg} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(404, JSON.encode!(%{erro: msg}))
    end
  end

  post "/reservas/:id/cancelar" do
    reserva_id = conn.path_params["id"]

    case MsReserva.cancelar_reserva(reserva_id) do
      {:ok, reserva} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, JSON.encode!(%{success: true, reserva: reserva}))
      {:erro, msg} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, JSON.encode!(%{success: false, erro: msg}))
    end
  end

  get "/promocoes" do
    case MsReserva.listar_promocoes() do
      {:ok, promocoes} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, JSON.encode!(%{promocoes: promocoes}))
      {:erro, msg} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(500, JSON.encode!(%{erro: msg}))
    end
  end

  get "/notificacoes/status" do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{ativo: true}))
  end

  post "/notificacoes/registrar" do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{success: true, mensagem: "Notificações ativadas"}))
  end

  post "/notificacoes/cancelar" do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{success: true, mensagem: "Notificações canceladas"}))
  end

  get "/sse/promocoes" do
    IO.puts("Nova conexão SSE solicitada")

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_header("access-control-allow-credentials", "true")
      |> send_chunked(200)

    # Registrar conexão SSE
    MsReserva.SSEManager.add_connection(self())

    # Enviar mensagem inicial
    case chunk(conn, "data: #{JSON.encode!(%{tipo: "conectado", mensagem: "Conexão SSE estabelecida"})}\n\n") do
      {:ok, conn} ->
        IO.puts("Mensagem inicial SSE enviada")
        maintain_sse_connection(conn)
      {:error, reason} ->
        IO.puts("Erro ao enviar mensagem inicial SSE: #{inspect(reason)}")
        :ok
    end
  end

  defp maintain_sse_connection(conn) do
    receive do
      {:sse_event, data} ->
        case chunk(conn, "data: #{JSON.encode!(data)}\n\n") do
          {:ok, conn} ->
            IO.puts("Evento SSE enviado com sucesso")
            maintain_sse_connection(conn)
          {:error, reason} ->
            IO.puts("Erro ao enviar evento SSE: #{inspect(reason)}")
            :ok
        end
      :close ->
        IO.puts("Conexão SSE fechada por comando")
        :ok
    after
      30_000 -> # Heartbeat a cada 30 segundos
        IO.puts("Enviando heartbeat SSE")
        case chunk(conn, "data: #{JSON.encode!(%{type: "heartbeat", timestamp: DateTime.utc_now()})}\n\n") do
          {:ok, conn} -> maintain_sse_connection(conn)
          {:error, reason} ->
            IO.puts("Erro no heartbeat SSE: #{inspect(reason)}")
            :ok
        end
    end
  end

  # Rota para lidar com caminhos não encontrados
  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, JSON.encode!(%{erro: "Endpoint não encontrado"}))
  end
end
