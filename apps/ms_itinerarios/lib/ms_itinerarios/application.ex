defmodule MsItinerarios.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {MsItinerarios, []},
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: MsItinerarios.Router,
        options: [port: 4002]
      )
    ]

    opts = [strategy: :one_for_one, name: MsItinerarios.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
