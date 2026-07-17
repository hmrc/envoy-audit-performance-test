RESULTS_DIR        ?= $(shell pwd)/results
ENVIRONMENT        ?= local

LOCUST_HOST ?= $(shell \
    case "$(ENVIRONMENT)" in \
        local) echo "http://localhost:9090" ;; \
        staging) echo "https://envoy-audit.staging.tax.service.gov.uk" ;; \
        qa) echo "https://envoy-audit.qa.tax.service.gov.uk" ;; \
        *) echo "http://localhost:9090" ;; \
    esac \
)

TEST_WORKERS       ?= $(shell nproc)
LOCUST_USERS       ?= 50
LOCUST_RUN_TIME    ?= 5m
LOCUST_SPAWN_RATE  ?= 5
AUDIT_LOSS_THRESHOLD_PCT ?= 1.0

RESOURCE_STATS     ?= $(RESULTS_DIR)/resource-stats.csv

test:
	mkdir -p $(RESULTS_DIR)
	@echo "timestamp,name,cpu_percent,mem_usage" > $(RESOURCE_STATS)
    @LOCUST_HOST=$(LOCUST_HOST) \
    LOCUST_USERS=$(LOCUST_USERS) \
    LOCUST_RUN_TIME=$(LOCUST_RUN_TIME) \
    LOCUST_SPAWN_RATE=$(LOCUST_SPAWN_RATE) \
    LOCUST_EXPECT_WORKERS=$(TEST_WORKERS) \
    AUDIT_LOSS_THRESHOLD_PCT=$(AUDIT_LOSS_THRESHOLD_PCT) \
    UID=`id -u` \
    sh -c 'docker compose up --build --scale worker=$(TEST_WORKERS) --exit-code-from controller & pid=$$!; \
    while kill -0 $$pid 2>/dev/null; do \
        ids=$$(docker compose ps -q controller worker || true); \
        if [ -n "$$ids" ]; then \
            docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" $$ids >> $(RESOURCE_STATS) 2>/dev/null || true; \
        fi; \
        sleep 1; \
    done; \
    wait $$pid'

clean:
	docker compose rm -sf
	rm -rf $(RESULTS_DIR)

smoke:
	$(MAKE) test LOCUST_USERS=1 LOCUST_RUN_TIME=30s LOCUST_SPAWN_RATE=1 TEST_WORKERS=1
