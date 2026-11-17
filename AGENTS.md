# AGENTS.md

## Overview
- Elixir umbrella app (apps_path: "apps") for cruise reservations. Domain language in code is Portuguese: reserva, bilhete, pagamento, itinerario, assinante, promocoes. Keep these terms as they are.

## Layout
- apps/front: Phoenix LiveView UI on port 4000, calls ms_reserva at http://localhost:4001 with Tesla. Routes in apps/front/lib/front_web/router.ex.
- apps/ms_reserva: GenServer + Plug.Router HTTP API on port 4001. Routes: GET /itinerarios/disponiveis, POST /itinerarios/reserva, GET /reservas, GET /reservas/:id
- apps/ms_pagamento, apps/ms_bilhete, apps/ms_marketing, apps/ms_subscriber: AMQP GenServers, no HTTP endpoint. ms_marketing declares the promocoes exchange and one queue per destino. ms_subscriber consumes promocoes-<destino> queues and supports inscrever_destino / cancelar_inscricao.

## Messaging
- RabbitMQ via amqp library. Exchange "cruzeiros" (direct) with routing keys: reserva-criada, pagamento-aprovado, pagamento-recusado, bilhete-gerado.
- Flow: ms_reserva publishes reserva-criada → ms_pagamento consumes and publishes pagamento-aprovado or pagamento-recusado → ms_bilhete consumes pagamento-aprovado and publishes bilhete-gerado → ms_reserva consumes pagamento-aprovado, pagamento-recusado, bilhete-gerado.
- ms_reserva binds queue pagamento-aprovado_ms_reserva to routing key pagamento-aprovado for its own copy.
- Exchange "promocoes" (direct) owned by ms_marketing. Queues named promocoes-<destino in lowercase>, routing key equals queue name.
- ms_pagamento signs messages. Keys in config/config.exs under :ms_pagamento (private_key) and :ms_reserva (public_key). ms_bilhete also reads :ms_reserva public_key. Never copy keys into docs or commits.

## Setup and run
- Start RabbitMQ: docker compose up rabbitmq
- Install deps: mix deps.get
- Front setup: cd apps/front && mix setup
- Run: iex -S mix phx.server. Front at http://localhost:4000, ms_reserva API at http://localhost:4001.

## Tests and checks
- mix test at root or inside an app (cd apps/<app> && mix test). mix format. mix compile --warnings-as-errors.
- RabbitMQ must be running for mix test and iex -S mix.

## Conventions
- One GenServer per service. JSON uses built-in JSON module; front uses Tesla.Middleware.JSON. Each app mix.exs sets build_path, deps_path, config_path to ../../. Run mix format before committing.

## Do not
- Commit secrets or keys. Change queue or exchange names without updating every producer and consumer. Add new HTTP ports without noting them here.