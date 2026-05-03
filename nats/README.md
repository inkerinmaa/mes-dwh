# NATS Broker with MQTT Support

NATS server running in Docker, configured to accept both native NATS connections and MQTT connections simultaneously.

## How it works

NATS is a high-performance messaging system. When MQTT support is enabled, NATS translates MQTT topics to NATS subjects:
- MQTT `QoS 0` = NATS core (fire and forget)
- MQTT `QoS 1/2` = NATS JetStream (persistent, at-least-once delivery)

JetStream is enabled so MQTT clients can use QoS 1 persistence.

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 4222 | TCP | Native NATS clients (nats.js, etc.) |
| 1883 | TCP | MQTT clients (mqttjs, mosquitto, etc.) |
| 8222 | HTTP | Monitoring dashboard & REST API |

## Start

```bash
docker compose up -d
```

## Monitor

- Web UI: http://localhost:8222
- Server info: http://localhost:8222/varz
- Connected clients: http://localhost:8222/connz
- Subscriptions: http://localhost:8222/subsz

## Stop

```bash
docker compose down
```

## Data persistence

JetStream data is stored in a Docker volume `nats-data`. To wipe all data:
```bash
docker compose down -v
```
