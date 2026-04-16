# KB: IBM MQ + Elastic Agent Docker Validation

## What this validates

This procedure confirms the full metrics flow:

1. IBM MQ exposes Prometheus metrics on port `9157`
2. Elastic Agent enrolls to Fleet
3. Metrics are written to Elasticsearch

## Prerequisites

- Docker is running
- Fleet URL and enrollment token are available
- Elasticsearch endpoint and credentials are available

## Quick Steps

1. Set environment variables

```bash
export FLEET_URL="https://<your-fleet-url>:443"
export FLEET_ENROLLMENT_TOKEN="<your-enrollment-token>"
export ELASTICSEARCH_HOSTS="https://<your-es-endpoint>:443"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="<your-password>"
```

2. Start IBM MQ + Elastic Agent

```bash
bash ./test-ibmmq-prometheus.sh
```

3. Run validation checks

```bash
bash ./validate-ibmmq-integration.sh
```

## Expected results

- `http://localhost:9157/metrics` is reachable
- `ibmmq_*` metrics are present
- Elastic Agent is healthy and connected
- IBM MQ metrics documents exist in Elasticsearch

## Stop and cleanup

```bash
docker stop ibmmq-test elastic-agent-test
```

## Common issues

- Missing `FLEET_URL` or `FLEET_ENROLLMENT_TOKEN`: the startup script exits immediately
- `9157/metrics` not reachable: check IBM MQ container status and port mapping
- No documents in Elasticsearch: verify ES URL/credentials and Fleet enrollment
