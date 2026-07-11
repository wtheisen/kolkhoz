# Production observability

Scrape `GET /metrics/prometheus`; `GET /metrics` remains the compatibility JSON
diagnostic. Metrics intentionally use bounded, low-cardinality route templates and
never contain session, user, command, or worker IDs.

Starter objectives:

- HTTP availability: 99.9% non-5xx responses over 30 days.
- accepted command completion: 99.9% within 2 seconds; zero dead letters.
- realtime delivery: fewer than 0.1% subscriber overflows.
- deadline processing: 99.9% of claims begin within 30 seconds of their deadline.

Load `prometheus-alerts.yml` into Prometheus-compatible rule evaluation. Page on
sustained availability, command, DLQ, or scheduler failures; ticket short lease-loss
or realtime-overflow bursts. Dashboard route status/latency, store latency/errors,
shard queue saturation, command lag, Redis health, subscribers, and scheduler lag.
