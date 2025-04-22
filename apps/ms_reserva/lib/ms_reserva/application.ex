defmodule MsReserva.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {
        MsReserva,
        []
      },
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: MsReserva.Router,
        options: [port: 4001]
      )
    ]

    opts = [strategy: :one_for_one, name: MsReserva.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
