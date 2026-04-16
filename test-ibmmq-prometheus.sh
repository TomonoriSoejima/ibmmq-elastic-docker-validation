#!/usr/bin/env bash
# Test IBM MQ + Elastic Agent integration end-to-end in Docker
# IBM MQ exposes Prometheus metrics on port 9157; Elastic Agent enrolls via Fleet

set -euo pipefail

IBMMQ_CONTAINER="ibmmq-test"
AGENT_CONTAINER="elastic-agent-test"

FLEET_URL="${FLEET_URL:-}"
ENROLLMENT_TOKEN="${FLEET_ENROLLMENT_TOKEN:-}"
AGENT_VERSION="9.3.3"

if [[ -z "$FLEET_URL" ]]; then
  echo "Error: Set FLEET_URL before running this script."
  exit 1
fi

if [[ -z "$ENROLLMENT_TOKEN" ]]; then
  echo "Error: Set FLEET_ENROLLMENT_TOKEN before running this script."
  exit 1
fi

# Elasticsearch endpoint (where agent sends collected metrics)
# For local ES on localhost: use 'http://host.docker.internal:9200' (Mac/Windows) or 'http://<your-ip>:9200' (Linux)
ES_HOSTS="${ELASTICSEARCH_HOSTS:-http://host.docker.internal:9200}"
ES_USERNAME="${ELASTICSEARCH_USERNAME:-elastic}"
ES_PASSWORD="${ELASTICSEARCH_PASSWORD:-changeme}"

# --- IBM MQ ---
echo "==> Starting IBM MQ container (amd64 via Rosetta emulation)..."
docker run --rm -d \
  --name "$IBMMQ_CONTAINER" \
  --platform linux/amd64 \
  -e LICENSE=accept \
  -e MQ_QMGR_NAME=QM1 \
  -e MQ_ENABLE_METRICS=true \
  -p 9157:9157 \
  -p 1414:1414 \
  icr.io/ibm-messaging/mq:latest

echo "==> Waiting for IBM MQ to start (30s)..."
sleep 30

echo "==> Testing Prometheus endpoint at localhost:9157/metrics..."
curl -sf http://localhost:9157/metrics | head -20

# --- Elastic Agent ---
echo ""
echo "==> Starting Elastic Agent container and enrolling to Fleet..."
docker run -d \
  --name "$AGENT_CONTAINER" \
  --network host \
  -e FLEET_ENROLL=1 \
  -e FLEET_URL="$FLEET_URL" \
  -e FLEET_ENROLLMENT_TOKEN="$ENROLLMENT_TOKEN" \
  -e ELASTICSEARCH_HOSTS="$ES_HOSTS" \
  -e ELASTICSEARCH_USERNAME="$ES_USERNAME" \
  -e ELASTICSEARCH_PASSWORD="$ES_PASSWORD" \
  docker.elastic.co/elastic-agent/elastic-agent:"$AGENT_VERSION"

echo ""
echo "==> Done. Containers running:"
echo "    IBM MQ:        docker logs $IBMMQ_CONTAINER"
echo "    Elastic Agent: docker logs $AGENT_CONTAINER"
echo ""
echo "==> Elasticsearch Configuration:"
echo "    Hosts:     $ES_HOSTS"
echo "    Username:  $ES_USERNAME"
echo ""
echo "==> To customize Elasticsearch endpoint, run with environment variables:"
echo "    FLEET_URL=https://your-fleet-url:443 FLEET_ENROLLMENT_TOKEN=yourtoken ELASTICSEARCH_HOSTS=http://your-cluster:9200 ELASTICSEARCH_USERNAME=elastic ELASTICSEARCH_PASSWORD=yourpass $0"
echo ""
echo "==> To stop everything:"
echo "    docker stop $IBMMQ_CONTAINER $AGENT_CONTAINER"
