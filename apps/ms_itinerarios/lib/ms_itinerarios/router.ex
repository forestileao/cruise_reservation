defmodule MsItinerarios.Router do
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

  # API para consultar itinerários disponíveis
  get "/itinerarios/disponiveis" do
    conn = Plug.Conn.fetch_query_params(conn)
    params = conn.query_params

    {:ok, itinerarios} = MsItinerarios.consultar_disponiveis(
      params["destino"],
      params["data_embarque"],
      params["porto_embarque"]
    )

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{itinerarios: itinerarios}))
  end

  # API para verificar disponibilidade de cabines
  post "/itinerarios/verificar" do
    IO.puts("Requisição POST recebida em /itinerarios/verificar")
    IO.puts("Headers: #{inspect(conn.req_headers)}")
    IO.puts("Body params: #{inspect(conn.body_params)}")

    # Verificar se o body foi parseado corretamente
    case conn.body_params do
      %Plug.Conn.Unfetched{} ->
        IO.puts("Body não foi parseado pelo Plug.Parsers, tentando ler manualmente")
        # Se não foi parseado, tentar ler manualmente
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        IO.puts("Body lido manualmente: #{inspect(body)}")

        case body do
          "" ->
            IO.puts("Body vazio!")
            conn
            |> put_resp_header("content-type", "application/json")
            |> send_resp(400, JSON.encode!(%{erro: "Body da requisição vazio"}))

          _ ->
            try do
              params = JSON.decode!(body)
              IO.puts("Params decodificados: #{inspect(params)}")
              processar_verificacao(conn, params)
            rescue
              JSON.DecodeError ->
                IO.puts("Erro ao decodificar JSON")
                conn
                |> put_resp_header("content-type", "application/json")
                |> send_resp(400, JSON.encode!(%{erro: "JSON inválido"}))
            end
        end

      params when is_map(params) ->
        IO.puts("Body parseado pelo Plug.Parsers: #{inspect(params)}")
        # Body foi parseado pelo Plug.Parsers
        processar_verificacao(conn, params)

      _ ->
        IO.puts("Formato de dados inválido: #{inspect(conn.body_params)}")
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, JSON.encode!(%{erro: "Formato de dados inválido"}))
    end
  end

  defp processar_verificacao(conn, params) do
    case MsItinerarios.verificar_disponibilidade(
      params["cruzeiro_id"],
      params["data_embarque"],
      params["num_cabines"]
    ) do
      {:ok, result} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, JSON.encode!(result))
      {:erro, msg} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, JSON.encode!(%{erro: msg}))
    end
  end

  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, JSON.encode!(%{erro: "Endpoint não encontrado"}))
  end
end
