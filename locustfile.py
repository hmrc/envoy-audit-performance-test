import os
import time
import threading
import logging
from locust import HttpUser, task, between, events
from locust.runners import MasterRunner

AUDIT_STUB_URL = os.getenv("AUDIT_STUB_URL", "http://cip-datastream-stub:8080")

# Shared counters for audit event delivery tracking
_requests_sent = 0
_lock = threading.Lock()

logger = logging.getLogger(__name__)


@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kwargs):
    if exception is None:
        global _requests_sent
        with _lock:
            _requests_sent += 1


class AuditPathUser(HttpUser):
    """
    Drives HTTP traffic through Envoy. Envoy's Lua filter intercepts each
    request and emits an audit event to the audit service, which forwards
    it to the CIP Datastream stub.
    """
    wait_time = between(0.05, 0.2)

    @task(8)
    def submit_small(self):
        self.client.post(
            "/submit",
            json={"payload": "x" * 1024},
            headers={"Content-Type": "application/json", "X-Request-ID": _request_id()},
            name="POST /submit",
        )

    @task(2)
    def submit_large(self):
        self.client.post(
            "/submit",
            json={"payload": "x" * (512 * 1024)},
            headers={"Content-Type": "application/json", "X-Request-ID": _request_id()},
            name="POST /submit (large)",
        )

    @task(3)
    def get_resource(self):
        self.client.get(
            "/resource",
            headers={"X-Request-ID": _request_id()},
            name="GET /resource",
        )


def _request_id() -> str:
    import uuid
    return str(uuid.uuid4())


@events.test_stop.add_listener
def check_audit_delivery(environment, **kwargs):
    """
    After the test, compare requests sent vs audit events received by the stub.
    Logs event loss percentage and fails the run if loss exceeds threshold.
    """
    import urllib.request, json as _json

    try:
        with urllib.request.urlopen(f"{AUDIT_STUB_URL}/audit/count", timeout=10) as resp:
            data = _json.loads(resp.read())
            events_received = data.get("count", 0)
    except Exception as exc:
        logger.warning("Could not reach CIP Datastream stub for audit count: %s", exc)
        return

    with _lock:
        sent = _requests_sent

    loss = max(0, sent - events_received)
    loss_pct = (loss / sent * 100) if sent > 0 else 0.0

    logger.info("=== Audit Delivery Summary ===")
    logger.info("Requests sent  : %d", sent)
    logger.info("Audit events   : %d", events_received)
    logger.info("Event loss     : %d (%.2f%%)", loss, loss_pct)

    LOSS_THRESHOLD_PCT = float(os.getenv("AUDIT_LOSS_THRESHOLD_PCT", "1.0"))
    if loss_pct > LOSS_THRESHOLD_PCT:
        logger.error("FAIL: Audit event loss %.2f%% exceeds threshold %.2f%%", loss_pct, LOSS_THRESHOLD_PCT)
        environment.process_exit_code = 1
