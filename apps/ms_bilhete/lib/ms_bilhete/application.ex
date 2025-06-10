defmodule MsBilhete.Application do


  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {
        MsBilhete,
        []
      },
    ]



    opts = [strategy: :one_for_one, name: MsBilhete.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
