defmodule MsPagamento.Application do


  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {MsPagamento, []},
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: MsPagamento.Router,
        options: [port: 4003]
      )
    ]

    opts = [strategy: :one_for_one, name: MsPagamento.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
