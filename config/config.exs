# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Signing key private and public
config :ms_pagamento, private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCp4D5caymp6A50\nYp1RC2+6qtbNrLtBqVHg/z7pIMJGluhqF9xZUEBZJh0uwSKhVbKjQ/jQ12OAVOpN\n1J/q14cAvHS0qt4URMAl5nm5v/5PCxaENUiUrXWaoZRh/gkWY/daIes4NW+Fus9d\nHcRSrrhY+CkXo+sVUtsTrsJzAb7Vu9CKaMLX71gnYFQwAsbXgBb7CxNJ5QbRGiBZ\nq+w/VzQobiZgHihCY//gbE+K652ZHKSGoHpNUlBTxSzdJZrqtChQh8lL/MatZcgL\nLSXQpAtYy+yVR9pIDn62byf2x+3VCRtLmZwnoHu4+gTLZo+hMChRLCGe6K3yHf4e\nZb+b0wYNAgMBAAECggEABjlyj4MDB81k74bIKja3uqiVLlFsmxSlLLqth2/tLmuh\nIHdiBN5tPSxUWBOOPUhylIuNC7nt/2nHxrT1FxnGlz77LROFsksX70uT8jvCtGAS\nTHiCAaX0GoezyX4RaddH3O7ukM9ZwsCm5cviwaon6bqjZtEEGsfqbGeJixqT7340\nMgXKgqTYDcBm2vJOrYGhu6Wv64ihpVFIcyBvb7Gj2hx1u420RgEACbDdB+fZVuHl\n/vw+7uXVBPLn/1q8yiQO8Nv33HhBHRPVQCc5InCTvZl66lJ08RiWJBOK+Y9Um7ua\naBH0fkVnDVzyfwCekT+d1Hdyf9zkGXCWrCPP9vle0QKBgQDqLRLfjb+mlK+lDsda\n0YkqLELBxewNbhqQfiK8RzXEX9/zHIkvVMKEkWBhia+TxKhwEcevLvdIgal/31iY\nzO9dCREYVcY0mOszEg2qHvuXTEtGcv0J4nvI1F4BZ79FSDU/1AxkxLGmzSDukVLB\nsokpmCGLPN12G47ou1KkgS++qwKBgQC5tRxDVQ7a8bxGcJD2EHM9REEvsoloeiPD\nIKpRW/FMapDGheF2wZKfjX5ZYhUZvjf8EtAz08p6zWzhfE0QYQ3h7Ju2vjJHmNr9\nu/NscxMc0zsWBZM+UjiH5m+iiD/c9WwmIIV7BcTmiVfAYLFGIOFfOq6WvaYohb+K\n3KBilt7uJwKBgFXp636xFpsa+cXowiMDtPsP+f31i0DyIDTa0guZZJSDSDp9Qadn\nxWW1oFKonQ3tnI5hN42CAZ9MUs9jNbH5nefYJ7lx3qH1aHT4LqM3cr5zczqJfWRe\n/2MS5tpFIdtdPowIU/O0Zij4IRjloCMISWJFOilHT0jBm5CvCQbpjoa5AoGAMlEV\nGFVKkh4fckJ7tIAeiUIeG2tXebxmRi9qlmLADYFuOqv5u/CU5rAyxMsjhncYui7q\nxLAk04Mndiz0wHRbi5RNWIVOIEIVS9yKBx9i1VOSVdQq4h7q/D9+jd4214qTw/zZ\nzcxxXjlmUlSgk6zDA8dlmKhIBgC/NkOzHSNdwc8CgYEAkX4nKkmBntO5Q1BFT3r1\nNDc5gkcWQI0H0agOG1+v/l95lQS7Ck93FuxwqAwQnzDa7Kv+g3sFVnShwhBmZxSv\nUj/FS8VyRKkbpkc4votzrCGN9WFXlGQ5htoKCWXS03Jp748Fo7VRuikvp1R+EaMz\n3FYdwqYKyEhB0HXtteQQ6Ns=\n-----END PRIVATE KEY-----\n"
config :ms_reserva, public_key: "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqeA+XGspqegOdGKdUQtv\nuqrWzay7QalR4P8+6SDCRpboahfcWVBAWSYdLsEioVWyo0P40NdjgFTqTdSf6teH\nALx0tKreFETAJeZ5ub/+TwsWhDVIlK11mqGUYf4JFmP3WiHrODVvhbrPXR3EUq64\nWPgpF6PrFVLbE67CcwG+1bvQimjC1+9YJ2BUMALG14AW+wsTSeUG0RogWavsP1c0\nKG4mYB4oQmP/4GxPiuudmRykhqB6TVJQU8Us3SWa6rQoUIfJS/zGrWXICy0l0KQL\nWMvslUfaSA5+tm8n9sft1QkbS5mcJ6B7uPoEy2aPoTAoUSwhnuit8h3+HmW/m9MG\nDQIDAQAB\n-----END PUBLIC KEY-----\n"

config :front,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :front, FrontWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FrontWeb.ErrorHTML, json: FrontWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Front.PubSub,
  live_view: [signing_salt: "0MJTClbB"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :front, Front.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  front: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/front/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  front: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/front/assets", __DIR__)
  ]




# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
