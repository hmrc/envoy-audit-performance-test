# envoy-audit-performance-test

Performance test suite for the Envoy-based audit solution.

## What it measures

| Metric | How |
|---|---|
| Request throughput (RPS) | Locust stats CSV + HTML report |
| Latency (p50/p95/p99) | Locust stats CSV + HTML report |
| Audit event delivery | Stub/audit/count vs requests sent |
| Audit event loss % | Logged at test end; fails build if > threshold |


## Prerequisites

- Docker + Docker Compose
- make
- Envoy + audit service running and reachable (staging or local)

## Running locally (smoke test)
make smoke LOCUST_HOST=http://localhost:10000
## Running a full test
make test \
  LOCUST_HOST=https://envoy-audit.protected.mdtp \
  LOCUST_USERS=100 \
  LOCUST_RUN_TIME=10m \
  LOCUST_SPAWN_RATE=10
Results are written to ./results/:
- report.html — Locust HTML report (throughput, latency charts)
- stats.csv, stats_history.csv, failures.csv — raw data
## Running in Jenkins

Trigger theenvoy-audit-performance-tests Jenkins job with parameters:

| Parameter | Default | Description |
|---|---|---|
|users | 50 | Concurrent users |
|duration | 5m | Test duration |
|spawn_rate | 5 | Users/sec ramp rate |
|envoy_host | staging URL | Envoy ingress |
|loss_threshold | 1.0 | Max audit loss % before fail |

## Interpreting results

1. Openresults/report.html for throughput and latency charts.
2. Check the test log for the=== Audit Delivery Summary === block — this shows event loss.
3. A non-zero Jenkins exit code means either latency SLOs were breached or audit loss exceeded the threshold.


## Regression use

Re-run with the same parameters before and after any change to Envoy config, Lua filter, or audit service. Compare `stats_history.csv` across runs.


---

## How to Test

### Locally (no Envoy yet — validate the suite itself)


# 1. Start stubs only
docker compose up --build cip-datastream-stub upstream

# 2. Point LOCUST_HOST at the upstream stub directly to verify Locust works
make smoke LOCUST_HOST=http://localhost:9090

# 3. Check results/report.html opens in browser
open results/report.html

