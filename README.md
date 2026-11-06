# CruiseReservation

Install and run the cruise reservation app from this repository.

## Requirements

- Elixir 1.18 or newer
- Docker

## Install and run

RabbitMQ must be up first. Start it from `docker-compose.yaml` (guest/guest, ports 5672 and 15672):

```sh
docker compose up -d rabbitmq
```

From the repository root, install dependencies:

```sh
mix deps.get
```

From `apps/front`, run setup. The `mix setup` alias lives only in `apps/front/mix.exs`:

```sh
cd apps/front && mix setup
```

From the repository root, start the app:

```sh
iex -S mix phx.server
```

- UI: http://localhost:4000
- Reserva API: http://localhost:4001
