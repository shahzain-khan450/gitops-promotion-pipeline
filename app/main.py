"""
The one app promoted dev -> staging -> prod. It reports its own environment
and image version so you can literally curl each cluster/namespace and see
proof of what's actually deployed where — the whole point of a promotion
pipeline demo.

ENVIRONMENT and APP_VERSION are injected via the ConfigMap each Kustomize
overlay generates (see k8s/overlays/*/kustomization.yaml).

Run locally:
    pip install -r requirements.txt
    ENVIRONMENT=local APP_VERSION=dev uvicorn main:app --host 0.0.0.0 --port 8000

Build + push:
    docker build -t ghcr.io/shahzain-khan450/gitops-demo-app:<tag> .
    docker push ghcr.io/shahzain-khan450/gitops-demo-app:<tag>
"""

import os
import socket
import time

from fastapi import FastAPI, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI(title="gitops-demo-app")

START_TIME = time.time()
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")
APP_VERSION = os.environ.get("APP_VERSION", "unknown")

REQUEST_COUNT = Counter(
    "http_requests_total", "Total HTTP requests", ["path", "environment"]
)


@app.middleware("http")
async def track_metrics(request, call_next):
    response = await call_next(request)
    REQUEST_COUNT.labels(path=request.url.path, environment=ENVIRONMENT).inc()
    return response


@app.get("/")
def root():
    return {
        "service": "gitops-demo-app",
        "environment": ENVIRONMENT,
        "version": APP_VERSION,
        "hostname": socket.gethostname(),
        "uptime_seconds": round(time.time() - START_TIME, 1),
    }


@app.get("/healthz")
def healthz():
    return {"status": "ok", "environment": ENVIRONMENT}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
