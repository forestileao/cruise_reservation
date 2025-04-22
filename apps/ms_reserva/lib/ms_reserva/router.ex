defmodule MsReserva.Router do
  use Plug.Router

  plug :match
  plug :dispatch

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

    # Chama a função que efetua a reserva
    {:ok, reserva} = MsReserva.efetuar_reserva(params["cruzeiro_id"], params["data_embarque"], params["num_passageiros"], params["num_cabines"])

    # Retorna a resposta em JSON
    send_resp(conn, 201, JSON.encode!(%{reserva: reserva}))
  end

  get "/reservas" do
    {:ok, reservas} = MsReserva.listar_reservas()

    # Retorna a resposta em JSON
    send_resp(conn, 200, JSON.encode!(%{reservas: reservas}))
  end


  get "/reservas/:id" do
    {:ok, status} = MsReserva.obter_status_reserva(conn.path_params["id"])

    # Retorna a resposta em JSON
    send_resp(conn, 200, JSON.encode!(%{reserva: status}))
  end

  # Rota para lidar com caminhos não encontrados
  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
