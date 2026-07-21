# envoy-audit-performance-test

Performance test suite for the Envoy audit path. This suite exercises traffic through Envoy, the Lua audit filter, the audit service transformation path, and delivery to a CIP Datastream stub.

## Repository structure

- Jenkinsfile — Jenkins pipeline for environment selection and test execution
- Makefile — local and CI entrypoint for the test suite
- compose.yaml — Docker Compose topology for Locust controller, worker, local upstream, and CIP Datastream stub
- locustfile.py — load scenario and audit delivery verification
- stubs/ — local mock services for the upstream target and CIP Datastream endpoint
- results/ — generated resource usage and test artifacts
- .gitignore — ignores generated files and local artifacts

## Prerequisites

- Docker and Docker Compose available on the host
- A shell with permissions to run docker compose
- If running against non-local environments, ensure network access to the target Envoy host

## How it works

- controller and worker services run the Locust load test
- stubs/upstream provides a local HTTP target for local mode
- stubs/cip-datastream-stub records audit events and exposes /audit/count
- The test compares HTTP requests sent through Envoy with audit events received by the stub
- Resource consumption is sampled during the test into results/resource-stats.csv

## Local testing

From the folder:

bash
cd /Users/pratulpatel/Documents/MDTP/envoy-audit-performance-test


Run a full local test:

bash
ENVIRONMENT=local make test


Run a quick smoke test:

bash
make smoke


Run against a remote environment:

bash
ENVIRONMENT=staging LOCUST_HOST=https://envoy-audit.staging.tax.service.gov.uk make test


Or for QA:

bash
ENVIRONMENT=qa LOCUST_HOST=https://envoy-audit.qa.tax.service.gov.uk make test


If the environment uses private DNS and the standard route name cannot be resolved from your Jenkins node, you can use a direct internal load balancer target and override the HTTP host header:

bash
ENVIRONMENT=staging \
  LOCUST_HOST=https://apigw-0-staging-public-ratqoratp-30b1985878c2e05c.elb.eu-west-2.amazonaws.com \
  LOCUST_HOST_HEADER=transaction-engine-frontend.public-rate.mdtp \
  make test


Notes:

- ENVIRONMENT controls the default host mapping inside Makefile
- ENVIRONMENT=local runs against the local stubs/upstream service via http://upstream:9090
- LOCUST_HOST can override the target host explicitly for remote test targets
- LOCUST_HOST_HEADER can be used when the direct LOCUST_HOST target requires a virtual host header
- TEST_WORKERS defaults to the host CPU core count using nproc or sysctl
- LOCUST_USERS, LOCUST_RUN_TIME, LOCUST_SPAWN_RATE, and AUDIT_LOSS_THRESHOLD_PCT are configurable via environment variables

## Interpreting results

- results/resource-stats.csv contains CPU and memory usage samples for the controller and worker services
- Locust console output shows:
  - request throughput
  - response latency
  - number of successful / failed requests
- At test stop, the audit stub reports:
  - requests sent
  - audit events received
  - event loss and loss percentage
- If AUDIT_LOSS_THRESHOLD_PCT is exceeded, the test run fails

## Jenkins integration

The Jenkinsfile defines a parameterized pipeline with:

- ENVIRONMENT (choice: local, staging, qa)
- LOCUST_HOST (optional override)
- LOCUST_HOST_HEADER (optional custom Host header for direct internal targets)
- users
- duration
- spawn_rate
- loss_threshold

It runs:
make test ENVIRONMENT=${ENVIRONMENT} LOCUST_HOST='${LOCUST_HOST}' \
  LOCUST_HOST_HEADER='${LOCUST_HOST_HEADER}' \
  TEST_WORKERS=${NUMBER_OF_CORES} LOCUST_USERS=${users} \
  LOCUST_RUN_TIME=${duration} LOCUST_SPAWN_RATE=${spawn_rate} \
  AUDIT_LOSS_THRESHOLD_PCT=${loss_threshold}


The Jenkins pipeline then archives results/* and cleans up Docker services after completion.

## Cleanup
To stop and remove containers and test artifacts:
make clean

