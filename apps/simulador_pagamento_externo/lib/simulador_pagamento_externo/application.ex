defmodule SimuladorPagamentoExterno.Application do
  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    children = [
      {SimuladorPagamentoExterno, []},
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: SimuladorPagamentoExterno.Router,
        options: [port: 4010]
      ),
    ]

    opts = [strategy: :one_for_one, name: SimuladorPagamentoExterno.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
