import Config



config :front, FrontWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "1f/m/NEizivWziupBSYrmpsHpk/gAIiTeMk8uRMsJueJ8lDakjiYkAnHXZfeMMbE",
  server: false


config :front, Front.Mailer, adapter: Swoosh.Adapters.Test


config :swoosh, :api_client, false


config :logger, level: :warning


config :phoenix, :plug_init_mode, :runtime


config :phoenix_live_view,
  enable_expensive_runtime_checks: true
