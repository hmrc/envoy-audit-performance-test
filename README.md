# envoy-audit-performance-test

Performance test suite for the Envoy audit path. This suite exercises traffic through Envoy, the Lua audit filter, the audit service transformation path, and delivery to a CIP Datastream stub.

## Repository structure

- Jenkinsfile— Jenkins pipeline for environment selection and test execution
- Makefile— local and CI entrypoint for the test suite
- compose.yaml— Docker Compose topology for Locust controller, worker, local upstream, and CIP Datastream stub
- locustfile.py— load scenario and audit delivery verification
- stubs/— local mock services for the upstream target and CIP Datastream endpoint
- results/— generated resource usage and test artifacts
- .gitignore— ignores generated files and local artifacts

## Prerequisites

- Docker and Docker Compose available on the host
- A shell with permissions to run docker compose
- If running against non-local environments, ensure network access to the target Envoy host

## How it works

- controllerand workerservices run the Locust load test
- stubs/upstreamprovides a local HTTP target for localmode
- stubs/cip-datastream-stubrecords audit events and exposes /audit/count
- The test compares HTTP requests sent through Envoy with audit events received by the stub
- Resource consumption is sampled during the test into results/resource-stats.csv

## Local testing

From the folder:
Run a full local test:
ENVIRONMENT=local make test
Run a quick smoke test:
make smoke
Run against a remote environment:


Notes:

- ENVIRONMENTcontrols the default host mapping inside Makefile
- ENVIRONMENT=localruns against the local stubs/upstreamservice via http://upstream:9090
- LOCUST_HOSTcan override the target host explicitly for remote test targets
- TEST_WORKERSdefaults to the host CPU core count using nprocor sysctl
- LOCUST_USERS, LOCUST_RUN_TIME, LOCUST_SPAWN_RATE, and AUDIT_LOSS_THRESHOLD_PCTare configurable via environment variables

## Interpreting results

- results/resource-stats.csvcontains CPU and memory usage samples for controllerand workerservices
- Locust console output shows:
  - request throughput
  - response latency
  - number of successful / failed requests
- At test stop, the audit stub reports:
  - requests sent
  - audit events received
  - event loss and loss percentage
- If AUDIT_LOSS_THRESHOLD_PCTis exceeded, the test run fails

## Jenkins integration

The Jenkinsfiledefines a parameterized pipeline with:

- ENVIRONMENT(choice: local, staging, qa)
- LOCUST_HOST(optional override)
- users
- duration
- spawn_rate
- loss_threshold

It runs:

bash
make test ENVIRONMENT=${ENVIRONMENT} LOCUST_HOST='${LOCUST_HOST}' \
  TEST_WORKERS=${NUMBER_OF_CORES} LOCUST_USERS=${users} \
  LOCUST_RUN_TIME=${duration} LOCUST_SPAWN_RATE=${spawn_rate} \
  AUDIT_LOSS_THRESHOLD_PCT=${loss_threshold}


The Jenkins pipeline then archives results/*and cleans up Docker services after completion.

## Cleanup

To stop and remove containers and test artifacts:
make clean

