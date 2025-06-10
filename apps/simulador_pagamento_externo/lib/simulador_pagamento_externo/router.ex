defmodule SimuladorPagamentoExterno.Router do
  use Plug.Router

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

  get "/pay/:reserva_id" do
    reserva_id = conn.path_params["reserva_id"]
    conn = Plug.Conn.fetch_query_params(conn)
    valor = conn.query_params["valor"] || "0"

    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Pagamento - Reserva #{reserva_id}</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-100">
        <div class="max-w-md mx-auto mt-10 bg-white p-6 rounded shadow">
            <h2 class="text-xl font-bold mb-4">Pagamento da Reserva</h2>
            <p><strong>Reserva:</strong> #{reserva_id}</p>
            <p><strong>Valor:</strong> R$ #{valor}</p>

            <div class="mt-6 space-y-4">
                <button onclick="processarPagamento('#{reserva_id}', #{valor})"
                        class="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded">
                    Pagar Agora
                </button>

                <p class="text-sm text-gray-600">
                    Este é um simulador. O pagamento será processado automaticamente
                    com 80% de chance de aprovação.
                </p>
            </div>

            <div id="resultado" class="mt-4"></div>
        </div>

        <script>
            function processarPagamento(reservaId, valor) {
                document.getElementById('resultado').innerHTML =
                    '<p class="text-blue-600">Processando pagamento...</p>';

                fetch('/processar', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({reserva_id: reservaId, valor: valor})
                })
                .then(response => response.json())
                .then(data => {
                    document.getElementById('resultado').innerHTML =
                        '<p class="text-green-600">Pagamento enviado para processamento!</p>' +
                        '<p class="text-sm">Você receberá uma notificação em breve.</p>';
                })
                .catch(error => {
                    document.getElementById('resultado').innerHTML =
                        '<p class="text-red-600">Erro ao processar pagamento.</p>';
                });
            }
        </script>
    </body>
    </html>
    """

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, html)
  end

  post "/processar" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    params = JSON.decode!(body)

    SimuladorPagamentoExterno.simular_processamento_pagamento(
      params["reserva_id"],
      params["valor"]
    )

    send_resp(conn, 200, JSON.encode!(%{
      status: "processando",
      mensagem: "Pagamento enviado para processamento"
    }))
  end

  match _ do
    send_resp(conn, 404, "Página não encontrada")
  end
end
