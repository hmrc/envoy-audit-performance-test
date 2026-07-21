RESULTS_DIR        ?= $(shell pwd)/results
ENVIRONMENT        ?= local

LOCUST_HOST ?= $(shell if [ "$(ENVIRONMENT)" = "local" ]; then echo "http://upstream:9090"; elif [ "$(ENVIRONMENT)" = "staging" ]; then echo "https://envoy-audit.staging.tax.service.gov.uk"; elif [ "$(ENVIRONMENT)" = "qa" ]; then echo "https://envoy-audit.qa.tax.service.gov.uk"; else echo "http://upstream:9090"; fi)
LOCUST_HOST_HEADER ?= $(LOCUST_HOST)

TEST_WORKERS ?= $(shell if command -v nproc >/dev/null 2>&1; then nproc; elif command -v sysctl >/dev/null 2>&1; then sysctl -n hw.ncpu; else echo 1; fi)
LOCUST_USERS       ?= 50
LOCUST_RUN_TIME    ?= 5m
LOCUST_SPAWN_RATE  ?= 5
AUDIT_LOSS_THRESHOLD_PCT ?= 1.0

RESOURCE_STATS     ?= $(RESULTS_DIR)/resource-stats.csv

test:
	mkdir -p $(RESULTS_DIR)
	@echo "timestamp,name,cpu_percent,mem_usage" > $(RESOURCE_STATS)
	@LOCUST_HOST=$(LOCUST_HOST) \
	LOCUST_HOST_HEADER=$(LOCUST_HOST_HEADER) \
	LOCUST_USERS=$(LOCUST_USERS) \
	LOCUST_RUN_TIME=$(LOCUST_RUN_TIME) \
	LOCUST_SPAWN_RATE=$(LOCUST_SPAWN_RATE) \
	LOCUST_EXPECT_WORKERS=$(TEST_WORKERS) \
	AUDIT_LOSS_THRESHOLD_PCT=$(AUDIT_LOSS_THRESHOLD_PCT) \
	UID=`id -u` \
	sh -c 'docker compose up --build --abort-on-container-exit --scale worker=$(TEST_WORKERS) & pid=$$!; \
	while kill -0 $$pid 2>/dev/null; do \
		ids=$$(docker compose ps -q controller worker || true); \
		if [ -n "$$ids" ]; then \
			docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" $$ids >> $(RESOURCE_STATS) 2>/dev/null || true; \
		fi; \
		sleep 1; \
	done; \
	wait $$pid; \
	exit_code=0; \
	for id in $$(docker compose ps -q); do \
		code=$$(docker inspect --format="{{.State.ExitCode}}" $$id 2>/dev/null || echo 0); \
		if [ "$$code" -ne 0 ]; then exit_code=$$code; fi; \
	done; \
	exit $$exit_code'

clean:
	docker compose rm -sf
	rm -rf $(RESULTS_DIR)

smoke:
	$(MAKE) test LOCUST_USERS=1 LOCUST_RUN_TIME=30s LOCUST_SPAWN_RATE=1 TEST_WORKERS=1
