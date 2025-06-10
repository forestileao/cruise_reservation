defmodule MsMarketing.MixProject do
  use Mix.Project

  def project do
    [
      app: :ms_marketing,
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
      mod: {MsMarketing.Application, []}
    ]
  end


  defp deps do
    [
      {:amqp, "~> 4.0"}
    ]
  end
end
