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

    send_resp(conn, 200, JSON.encode!(%{itinerarios: itinerarios}))
  end

  # API para verificar disponibilidade de cabines
  post "/itinerarios/verificar" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    params = JSON.decode!(body)

    case MsItinerarios.verificar_disponibilidade(
      params["cruzeiro_id"],
      params["data_embarque"],
      params["num_cabines"]
    ) do
      {:ok, result} ->
        send_resp(conn, 200, JSON.encode!(result))
      {:erro, msg} ->
        send_resp(conn, 400, JSON.encode!(%{erro: msg}))
    end
  end

  match _ do
    send_resp(conn, 404, JSON.encode!(%{erro: "Endpoint não encontrado"}))
  end
end
