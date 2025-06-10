defmodule MsReserva.MixProject do
  use Mix.Project

  def project do
    [
      app: :ms_reserva,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end


  def application do
    [
      extra_applications: [:logger],
      mod: {MsReserva.Application, []}
    ]
  end


  defp deps do
    [
      {:amqp, "~> 4.0"},
      {:plug_cowboy, "~> 2.5"},
      {:cors_plug, "~> 3.0"},
      {:plug, "~> 1.14"},
      {:httpoison, "~> 2.0"}    ]
  end
end
