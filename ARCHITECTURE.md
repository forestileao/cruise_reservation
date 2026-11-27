# CruiseReservation Architecture

## Overview

CruiseReservation is an Elixir umbrella application for cruise reservation management. It uses a microservice architecture with asynchronous messaging through RabbitMQ.

Six applications run under the umbrella:

- **front** — Phoenix LiveView web UI
- **ms_reserva** — Reservation and itinerary API
- **ms_pagamento** — Payment processing
- **ms_bilhete** — Ticket (bilhete) generation
- **ms_marketing** — Promotion publishing
- **ms_subscriber** — Promotion consumption and display

The domain language is Portuguese. Terms such as reserva, bilhete, pagamento, itinerario, assinante, and promocoes appear throughout the code.

## Service communication

### Synchronous HTTP

The front application calls ms_reserva over HTTP at `http://localhost:4001` using the Tesla library. These API endpoints exist:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/itinerarios/disponiveis` | List itineraries (optional filters: destino, data_embarque, porto_embarque) |
| POST | `/itinerarios/reserva` | Create a reservation |
| GET | `/reservas` | List all reservations |
| GET | `/reservas/:id` | Get a single reservation by ID |

### Asynchronous messaging (RabbitMQ)

The remaining services communicate exclusively through RabbitMQ. Two exchanges exist:

#### Exchange "cruzeiros" (direct)

This exchange carries the reservation lifecycle. Each routing key has one or more consumers:

```
reserva-criada ──→ ms_pagamento
pagamento-aprovado ──→ ms_bilhete, ms_reserva
pagamento-recusado ──→ ms_reserva
bilhete-gerado ──→ ms_reserva
```

The flow is:

1. **ms_reserva** publishes `reserva-criada` after a user creates a reservation.
2. **ms_pagamento** consumes `reserva-criada`, processes payment (random approval or rejection), signs the result with RSA-SHA256, and publishes either `pagamento-aprovado` or `pagamento-recusado`.
3. **ms_bilhete** consumes `pagamento-aprovado`, verifies the signature using the ms_reserva public key, generates a ticket, and publishes `bilhete-gerado`.
4. **ms_reserva** consumes all three result messages (`pagamento-aprovado`, `pagamento-recusado`, `bilhete-gerado`) and updates the reservation status accordingly.

ms_reserva binds a dedicated queue `pagamento-aprovado_ms_reserva` to the `pagamento-aprovado` routing key so that both ms_bilhete and ms_reserva receive a copy of each approved payment message.

#### Exchange "promocoes" (direct)

**ms_marketing** owns this exchange. It declares one queue per destination (for example `promocoes-caribe`, `promocoes-mediterraneo`). The routing key equals the queue name. ms_marketing publishes promotions periodically (every 5 seconds) and on demand.

**ms_subscriber** subscribes to destination queues and prints each received promotion to stdout.

## Service details

### front

- Phoenix LiveView application on port 4000.
- Routes: `/` (HomeLive), `/reservas` (ReservaLive.Index), `/reservas/nova` (ReservaLive.New), `/reservas/:id` (ReservaLive.Show), `/assinante` (AssinanteLive).
- Calls ms_reserva over HTTP with Tesla. No direct RabbitMQ interaction.

### ms_reserva

- GenServer and Plug.Router HTTP API on port 4001.
- Maintains an in-memory map of itineraries (three hardcoded cruise options: Caribe, Mediterraneo, Alasca) and reservations.
- Publishes `reserva-criada` on new reservations.
- Consumes `pagamento-aprovado`, `pagamento-recusado`, and `bilhete-gerado`.
- Verifies message signatures using the ms_reserva public key.
- Supports callback registration per reservation (`registrar_callback/2`).

### ms_pagamento

- AMQP GenServer. No HTTP endpoint.
- Consumes `reserva-criada`.
- Randomly approves or rejects payments (50% chance each).
- Signs messages with RSA-SHA256 using the ms_pagamento private key.
- Publishes `pagamento-aprovado` or `pagamento-recusado`.

### ms_bilhete

- AMQP GenServer. No HTTP endpoint.
- Consumes `pagamento-aprovado`.
- Verifies the message signature using the ms_reserva public key.
- Generates a ticket with a random verification code and publishes `bilhete-gerado`.
- Exposes `obter_bilhete/1` to look up generated tickets.

### ms_marketing

- AMQP GenServer. No HTTP endpoint.
- Owns the "promocoes" exchange.
- Seeds two initial promotions at startup.
- Publishes a random promotion every 5 seconds.
- Exposes `publicar_promocao/5` and `listar_promocoes_ativas/0`.

### ms_subscriber

- AMQP GenServer. No HTTP endpoint.
- Subscribes to a configurable list of destination promotion queues.
- Prints received promotions to stdout with destination, title, description, discount, and validity.
- Supports `inscrever_destino/1`, `cancelar_inscricao/1`, and `listar_destinos_inscritos/0`.

## Message signing

ms_pagamento signs every `pagamento-aprovado` and `pagamento-recusado` message with RSA-SHA256. The payload structure is:

```json
{
  "mensagem": { ... },
  "assinatura": "<base64-encoded signature>"
}
```

ms_reserva and ms_bilhete verify the signature before processing. Keys are configured in `config/config.exs` under `:ms_pagamento` (private_key) and `:ms_reserva` (public_key).

## Configuration

- Build path, deps path, and config path are shared at the umbrella root. Each app's `mix.exs` sets these to `../../`.
- RabbitMQ connection uses default settings (`guest`/`guest` on localhost:5672).
- Keys for message signing live in `config/config.exs`.

## Running the application

1. Start RabbitMQ: `docker compose up -d rabbitmq`
2. Install dependencies: `mix deps.get`
3. Run front setup: `cd apps/front && mix setup`
4. Start all services: `iex -S mix phx.server`

The front is available at `http://localhost:4000` and the reservation API at `http://localhost:4001`.

## Testing

- Run tests from the root: `mix test`
- Or inside a single app: `cd apps/<app> && mix test`
- RabbitMQ must be running for tests that start services.
- Run `mix format` and `mix compile --warnings-as-errors` before committing.