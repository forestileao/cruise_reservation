# Cruise Reservation

Elixir umbrella for cruise reservations. A Phoenix LiveView front talks to an HTTP reservation service. Messaging services handle pagamento, bilhetes, marketing, and promocao subscriptions.

Domain terms in the code stay in Portuguese: reserva, bilhete, pagamento, itinerario, assinante, promocoes.

## Apps

| App | Role |
| --- | --- |
| `apps/front` | Phoenix LiveView UI. Calls `ms_reserva` over HTTP. |
| `apps/ms_reserva` | GenServer plus a Plug HTTP API for itinerarios and reservas. |
| `apps/ms_pagamento` | AMQP consumer/publisher for pagamento. No HTTP endpoint. |
| `apps/ms_bilhete` | AMQP service that emits bilhetes. No HTTP endpoint. |
| `apps/ms_marketing` | Declares the promocoes exchange and one queue per destino, and publishes promocoes. |
| `apps/ms_subscriber` | Consumes promocoes queues for subscribed destinos and prints each promocao. Supports `inscrever_destino` and `cancelar_inscricao`. |

## Prerequisites

- Elixir 1.18 or newer (service apps declare `~> 1.18`)
- Docker, to run RabbitMQ
- RabbitMQ (started from Compose; do not treat the commented `front` service in `docker-compose.yaml` as a supported run path)

## Run locally

Services open a default AMQP connection on startup, so RabbitMQ must already be running before tests or the interactive server.

1. From the repo root, start RabbitMQ:

   ```sh
   docker compose up rabbitmq
   ```

   Credentials are `guest` / `guest`. Broker port is `5672`. Management UI is `http://localhost:15672`.

2. From the repo root, install dependencies:

   ```sh
   mix deps.get
   ```

3. From `apps/front`, run setup. That alias installs dependencies and builds Tailwind and esbuild assets. The root mix file has no `setup` alias.

   ```sh
   cd apps/front && mix setup
   ```

4. From the repo root, start the umbrella:

   ```sh
   iex -S mix phx.server
   ```

## Local URLs

- Front: http://localhost:4000
- Reservation API (`ms_reserva`): http://localhost:4001

`ms_reserva` routes:

- `GET /itinerarios/disponiveis`
- `POST /itinerarios/reserva`
- `GET /reservas`
- `GET /reservas/:id`

## Message flow

RabbitMQ is used through the `amqp` library with default connection settings.

The `cruzeiros` exchange (direct) carries reserva, pagamento, and bilhete events. Routing keys and queues: `reserva-criada`, `pagamento-aprovado`, `pagamento-recusado`, `bilhete-gerado`.

- `ms_reserva` publishes `reserva-criada`.
- `ms_pagamento` consumes `reserva-criada` and publishes `pagamento-aprovado` or `pagamento-recusado`.
- `ms_bilhete` consumes `pagamento-aprovado` and publishes `bilhete-gerado`.
- `ms_reserva` consumes `pagamento-aprovado`, `pagamento-recusado`, and `bilhete-gerado`.

`ms_reserva` binds its own queue `pagamento-aprovado_ms_reserva` to the routing key `pagamento-aprovado`, so it and `ms_bilhete` each get a copy.

The `promocoes` exchange (direct) is owned by `ms_marketing`. Queues are named `promocoes-<destino in lowercase>` (for example `promocoes-caribe`), and the routing key equals the queue name. `ms_subscriber` consumes those queues.

`ms_pagamento` signs its messages and consumers verify the signature. Keys live in config; this README does not include them.

## Checks

RabbitMQ must be running for `mix test` and for `iex -S mix phx.server`.

From the repo root:

```sh
mix test
mix format
mix compile --warnings-as-errors
```

You can also run tests inside one app: `cd apps/<app> && mix test`.

The generated tests in `apps/ms_*/test` still call a removed `hello/0`, so those tests fail today.
