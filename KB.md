# KB: IBM MQ + Elastic Agent Docker Validation

## Goal

Validate that IBM MQ Prometheus metrics are collected by Elastic Agent and sent to Elasticsearch.

## Where the code is

The code is here: https://github.com/TomonoriSoejima/ibmmq-elastic-docker-validation

## Prerequisites

- Docker is running
- Fleet URL
- Fleet enrollment token
- Elasticsearch endpoint and credentials

## 1) Set environment variables

```bash
export FLEET_URL="https://<your-fleet-url>:443"
export FLEET_ENROLLMENT_TOKEN="<your-enrollment-token>"
export ELASTICSEARCH_HOSTS="https://<your-es-endpoint>:443"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="<your-password>"
```

## 2) Start IBM MQ and Elastic Agent

```bash
bash ./test-ibmmq-prometheus.sh
```

## 3) Run validation checks

```bash
bash ./validate-ibmmq-integration.sh
```

## Expected result

- `http://localhost:9157/metrics` is reachable
- `ibmmq_*` metrics are present
- Elastic Agent is healthy and connected
- Metrics documents are visible in Elasticsearch

## Cleanup

```bash
docker stop ibmmq-test elastic-agent-test
```

## Common issues

- Missing `FLEET_URL` or `FLEET_ENROLLMENT_TOKEN`: startup script exits with error
- Prometheus endpoint not reachable: check IBM MQ container and port mapping
- No documents in Elasticsearch: verify Elasticsearch URL, credentials, and Fleet enrollment

## Clarification: "Prometheus endpoint" does not mean "Prometheus server"

The integration UI says:

> specify Hostname and Port of Prometheus endpoint (`/metrics`)

This does **not** mean you need to run a Prometheus server.

"Prometheus endpoint" = "a URL that exposes metrics in Prometheus text format," e.g.:

```
http://<host>:9157/metrics
```

### Where does the endpoint come from?

The IBM MQ container itself. When started with `MQ_ENABLE_METRICS=true`, it:

- starts an internal HTTP server
- exposes `/metrics` on port `9157`
- outputs Prometheus-format metrics

### Actual architecture (minimum for qmgr metrics)

```
IBM MQ container  →  exposes :9157/metrics
Elastic Agent     →  scrapes :9157/metrics  →  Elasticsearch
```

No Prometheus container required.

### Limitation

This `/metrics` endpoint only exists when IBM MQ is running as a container. Non-containerized IBM MQ does not expose this endpoint, so qmgr metrics will not work with this integration.
