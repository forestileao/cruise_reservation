defmodule MsSubscriber.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {MsSubscriber, [destinos: ["Caribe", "Mediterrâneo", "Alasca", "Brasil", "Ásia"]]},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MsSubscriber.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
