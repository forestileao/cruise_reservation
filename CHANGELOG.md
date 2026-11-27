# CHANGELOG

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial project structure with Elixir umbrella app.
- Front: Phoenix LiveView UI on port 4000.
- ms_reserva: GenServer and Plug.Router HTTP API on port 4001.
- ms_pagamento: AMQP GenServer for payment processing.
- ms_bilhete: AMQP GenServer for ticket generation.
- ms_marketing: AMQP GenServer for promotions.
- ms_subscriber: AMQP GenServer for promotion subscriptions.
- RabbitMQ messaging between services via AMQP.