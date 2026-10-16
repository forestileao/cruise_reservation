# AGENTS.md

## Overview
- Elixir umbrella app (apps_path: "apps") for cruise reservations.
- Domain language in code is Portuguese: reserva, bilhete, pagamento, itinerario, assinante, promocoes. Keep these terms as they are.

## Layout
- apps/front: Phoenix LiveView UI on port 4000 (config/dev.exs). Calls ms_reserva over HTTP with Tesla at http://localhost:4001. See apps/front/lib/front_web/reserva_live/index.ex, show.ex, new.ex and home_live.ex. LiveView routes are in apps/front/lib/front_web/router.ex.
- apps/ms_reserva: GenServer plus a Plug.Router HTTP API on port 4001 (apps/ms_reserva/lib/ms_reserva/application.ex, router.ex). Routes:
  - GET /itinerarios/disponiveis
  - POST /itinerarios/reserva
  - GET /reservas
  - GET /reservas/:id
- apps/ms_pagamento: AMQP GenServer, no HTTP endpoint.
- apps/ms_bilhete: AMQP GenServer, no HTTP endpoint.
- apps/ms_marketing: AMQP GenServer, no HTTP endpoint. Declares the promocoes exchange and one queue per destino, and publishes promocoes.
- apps/ms_subscriber: AMQP GenServer, no HTTP endpoint. Consumes promocoes queues (promocoes-<destino in lowercase>) for the destinos it subscribes to and prints each promocao to stdout. It supports inscrever_destino and cancelar_inscricao.

## Messaging
- RabbitMQ through the amqp library. Services call AMQP.Connection.open() with default settings.
- Exchange "cruzeiros" (direct) carries these routing keys and queues: reserva-criada, pagamento-aprovado, pagamento-recusado, bilhete-gerado.
- Flow:
  - ms_reserva publishes reserva-criada.
  - ms_pagamento consumes reserva-criada and publishes pagamento-aprovado or pagamento-recusado.
  - ms_bilhete consumes pagamento-aprovado and publishes bilhete-gerado.
  - ms_reserva consumes pagamento-aprovado, pagamento-recusado and bilhete-gerado.
- ms_reserva binds its own queue pagamento-aprovado_ms_reserva to the routing key pagamento-aprovado, so it and ms_bilhete each get a copy.
- Exchange "promocoes" (direct) is owned by ms_marketing. Queues are named promocoes-<destino in lowercase> (for example promocoes-caribe), and the routing key equals the queue name.
- ms_pagamento signs its messages. Consumers verify the signature. Keys are in config/config.exs under :ms_pagamento (private_key) and :ms_reserva (public_key). ms_bilhete also reads :ms_reserva public_key. Never copy key values into docs or commits.

## Setup and run
- Start RabbitMQ: docker compose up rabbitmq (guest/guest, ports 5672 and 15672 for the management UI).
- Install deps from the root: mix deps.get
- Front setup (alias defined in apps/front/mix.exs): cd apps/front && mix setup
- Run everything from the root: iex -S mix phx.server
- Front is at http://localhost:4000 and the ms_reserva API at http://localhost:4001.

## Tests and checks
- mix test at the root, or inside one app (cd apps/<app> && mix test).
- mix format
- mix compile --warnings-as-errors
- The generated tests in apps/ms_*/test still assert a hello/0 function that no longer exists, so those tests fail today.
- The services connect to RabbitMQ when they start, so RabbitMQ must be running for mix test and iex -S mix to work.

## Conventions
- One GenServer per service, started from its Application module.
- JSON uses the built-in JSON module (JSON.encode!, JSON.decode!) in the services. Front uses Tesla.Middleware.JSON.
- Keep Portuguese names consistent with existing code.
- Deps, build and config are shared at the root: each app mix.exs sets build_path, deps_path and config_path to ../../.
- Run mix format before committing.

## Do not
- Commit secrets or keys.
- Change queue or exchange names without updating every producer and consumer.
- Add new HTTP ports without noting them here.
