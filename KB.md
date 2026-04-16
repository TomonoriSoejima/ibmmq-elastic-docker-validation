# KB: Validate IBM MQ Prometheus Metrics with Elastic Agent in Docker

## Summary

This KB describes how to validate IBM MQ metric ingestion end-to-end using Docker.

Validated flow:

1. IBM MQ exposes Prometheus metrics on port 9157.
2. Elastic Agent enrolls with Fleet.
3. Metrics are ingested into Elasticsearch.

## Steps

1. Export required environment variables.

```bash
export FLEET_URL="https://<your-fleet-url>:443"
export FLEET_ENROLLMENT_TOKEN="<your-enrollment-token>"
export ELASTICSEARCH_HOSTS="https://<your-es-endpoint>:443"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="<your-password>"
```

2. Start the test stack.

```bash
bash ./test-ibmmq-prometheus.sh
```

3. Validate end-to-end status.

```bash
bash ./validate-ibmmq-integration.sh
```

4. Confirm key outcomes.
- `http://localhost:9157/metrics` is reachable.
- `ibmmq_*` metrics exist at the exporter endpoint.
- Elastic Agent reports healthy and connected state.
- IBM MQ metrics documents are visible in Elasticsearch.

5. Stop containers when done.

```bash
docker stop ibmmq-test elastic-agent-test
```

## Troubleshooting quick notes

- Missing `FLEET_URL` or `FLEET_ENROLLMENT_TOKEN`: script exits with a clear error.
- Prometheus endpoint unreachable: check IBM MQ container status and port mapping.
- No data in Elasticsearch: verify output credentials, endpoint, and Fleet enrollment state.
