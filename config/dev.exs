import Config



#



config :front, FrontWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "RuThDzMPph/DWHTt3cqGPL790x2Oyr7qmLuJ23LDylgIdTp+wxDV5Sn5/aplqui2",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:front, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:front, ~w(--watch)]}
  ]


#



#

#

#

#






#





config :front, FrontWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/front_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]


config :front, dev_routes: true


config :logger, :console, format: "[$level] $message\n"



config :phoenix, :stacktrace_depth, 20


config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true


config :swoosh, :api_client, false
