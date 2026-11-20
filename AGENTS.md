# AGENTS.md

## Overview
Elixir umbrella app (apps_path: "apps") for cruise reservations. Portuguese domain language: reserva, bilhete, pagamento, itinerario, assinante, promocoes.

## Layout
- **apps/front**: Phoenix LiveView UI (port 4000). Calls ms_reserva via Tesla at localhost:4001.
- **apps/ms_reserva**: GenServer + Plug.Router HTTP API (port 4001). Routes: GET /itinerarios/disponiveis, POST /itinerarios/reserva, GET /reservas, GET /reservas/:id.
- **apps/ms_pagamento**, **ms_bilhete**, **ms_marketing**, **ms_subscriber**: AMQP GenServers, no HTTP.

## Messaging
- Exchange "cruzeiros" (direct): reserva-criada, pagamento-aprovado, pagamento-recusado, bilhete-gerado. ms_reserva publishes reserva-criada; ms_pagamento consumes and publishes pagamento-aprovado/recusado; ms_bilhete consumes pagamento-aprovado and publishes bilhete-gerado; ms_reserva consumes all three. ms_reserva binds pagamento-aprovado_ms_reserva so it and ms_bilhete each get a copy.
- Exchange "promocoes" (direct, owned by ms_marketing): queues named promocoes-<destino>. ms_subscriber consumes subscribed destinos.

## Setup
- `docker compose up rabbitmq` then `mix deps.get` from root, `cd apps/front && mix setup`, then `iex -S mix phx.server` from root.

## Tests
- `mix test`, `mix format`, `mix compile --warnings-as-errors` from root or per app. RabbitMQ must be running.

## Conventions
- One GenServer per service. JSON via built-in JSON module (Tesla.Middleware.JSON in front). Shared deps/config at root (build_path, deps_path, config_path: ../../). Run mix format before commit.

## Do not
- Commit keys/secrets. Change queue/exchange names without updating all consumers. Add HTTP ports without noting here.