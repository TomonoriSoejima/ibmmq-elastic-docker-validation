# IBM MQ + Elastic Agent Docker Validation

Public example scripts to validate IBM MQ metric collection with Elastic Agent in Docker.

**No Prometheus server required.** IBM MQ exposes metrics in Prometheus format directly on port `9157`. Elastic Agent scrapes that endpoint and ships data to Elasticsearch.

```
IBM MQ container  →  :9157/metrics  →  Elastic Agent  →  Elasticsearch
```

This is enabled by setting `MQ_ENABLE_METRICS=true` on the IBM MQ container. The IBM MQ integration UI refers to this URL as the "Prometheus endpoint" — it means the metrics URL, not a separate Prometheus server.

> **Note:** This `/metrics` endpoint is only available when IBM MQ runs as a container. Non-containerized IBM MQ does not expose this endpoint, so queue manager metrics will not work with this integration.

## What this repository contains

- `test-ibmmq-prometheus.sh`: Starts IBM MQ and Elastic Agent containers for an end-to-end test.
- `validate-ibmmq-integration.sh`: Runs validation checks (container status, Prometheus endpoint, Fleet connectivity, Elasticsearch data).
- `KB.md`: Step-by-step runbook you can share with customers.

## Security notes

- No hardcoded enrollment token is stored in this repository.
- No hardcoded Fleet URL is stored in this repository.
- Provide secrets and environment-specific values only at runtime via environment variables.

## Prerequisites

- Docker
- bash
- curl
- python3
- Access to Fleet and Elasticsearch

## Quick start

```bash
export FLEET_URL="https://<your-fleet-url>:443"
export FLEET_ENROLLMENT_TOKEN="<your-enrollment-token>"
export ELASTICSEARCH_HOSTS="https://<your-es-endpoint>:443"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="<your-password>"

bash ./test-ibmmq-prometheus.sh
bash ./validate-ibmmq-integration.sh
```

## Cleanup

```bash
docker stop ibmmq-test elastic-agent-test
```

## Disclaimer

This repository is a reproducible example for validation and troubleshooting. Review and adjust for production use.
