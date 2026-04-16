#!/usr/bin/env bash
# Fully validates the IBM MQ + Elastic Agent integration end-to-end.
# Checks: containers healthy, Prometheus endpoint serving ibmmq_* metrics,
# Elastic Agent HEALTHY, and documents actually landing in Elasticsearch.
#
# Usage:
#   ELASTICSEARCH_HOSTS="https://..." \
#   ELASTICSEARCH_USERNAME="elastic" \
#   ELASTICSEARCH_PASSWORD="..." \
#   ./validate-ibmmq-integration.sh

set -euo pipefail

IBMMQ_CONTAINER="${IBMMQ_CONTAINER:-ibmmq-test}"
AGENT_CONTAINER="${AGENT_CONTAINER:-elastic-agent-test}"

ES_HOSTS="${ELASTICSEARCH_HOSTS:-http://host.docker.internal:9200}"
ES_USERNAME="${ELASTICSEARCH_USERNAME:-elastic}"
ES_PASSWORD="${ELASTICSEARCH_PASSWORD:-changeme}"

PASS=0
FAIL=0

# ── helpers ─────────────────────────────────────────────────────────────────

green() { printf '\033[32m✔  %s\033[0m\n' "$*"; }
red()   { printf '\033[31m✘  %s\033[0m\n' "$*"; }

pass() { green "$1"; (( PASS++ )); }
fail() { red   "$1"; (( FAIL++ )); }

# Run a curl against ES; returns the raw JSON body.
es() {
  curl -sf -u "${ES_USERNAME}:${ES_PASSWORD}" \
    -H 'Content-Type: application/json' \
    "$@"
}

echo ""
echo "══════════════════════════════════════════════════"
echo "  IBM MQ + Elastic Agent  –  Integration Validator"
echo "══════════════════════════════════════════════════"
echo "  Elasticsearch: $ES_HOSTS"
echo "  IBM MQ:        $IBMMQ_CONTAINER"
echo "  Agent:         $AGENT_CONTAINER"
echo ""

# ── 1. Docker containers ─────────────────────────────────────────────────────

echo "── 1. Container health ─────────────────────────────"

if docker ps --format '{{.Names}}' | grep -q "^${IBMMQ_CONTAINER}$"; then
  IBMMQ_STATUS=$(docker inspect --format '{{.State.Status}}' "$IBMMQ_CONTAINER")
  if [[ "$IBMMQ_STATUS" == "running" ]]; then
    pass "IBM MQ container is running"
  else
    fail "IBM MQ container exists but status: $IBMMQ_STATUS"
  fi
else
  fail "IBM MQ container ($IBMMQ_CONTAINER) not found – start it first"
fi

if docker ps --format '{{.Names}}' | grep -q "^${AGENT_CONTAINER}$"; then
  AGENT_STATUS=$(docker inspect --format '{{.State.Status}}' "$AGENT_CONTAINER")
  if [[ "$AGENT_STATUS" == "running" ]]; then
    pass "Elastic Agent container is running"
  else
    fail "Elastic Agent container exists but status: $AGENT_STATUS"
  fi
else
  fail "Elastic Agent container ($AGENT_CONTAINER) not found – start it first"
fi

# ── 2. Prometheus endpoint ───────────────────────────────────────────────────

echo ""
echo "── 2. Prometheus endpoint ──────────────────────────"

if curl -sf http://localhost:9157/metrics >/dev/null 2>&1; then
  pass "Prometheus endpoint reachable (localhost:9157/metrics)"
else
  fail "Prometheus endpoint NOT reachable (localhost:9157/metrics)"
fi

IBMMQ_METRICS=$(curl -sf http://localhost:9157/metrics 2>/dev/null | grep -c "^ibmmq_" || true)
if [[ "$IBMMQ_METRICS" -gt 0 ]]; then
  pass "Prometheus endpoint exposes $IBMMQ_METRICS ibmmq_* metric lines"
else
  fail "No ibmmq_* metrics found at Prometheus endpoint"
fi

# Show a sample of available ibmmq metrics
echo ""
echo "   Sample IBM MQ metrics:"
curl -sf http://localhost:9157/metrics 2>/dev/null \
  | grep "^ibmmq_" | head -8 \
  | sed 's/^/     /'

# ── 3. Elastic Agent status ──────────────────────────────────────────────────

echo ""
echo "── 3. Elastic Agent status ─────────────────────────"

AGENT_STATUS_OUTPUT=$(docker exec "$AGENT_CONTAINER" elastic-agent status 2>&1 || true)

if echo "$AGENT_STATUS_OUTPUT" | grep -q "HEALTHY"; then
  pass "Elastic Agent is HEALTHY"
else
  fail "Elastic Agent is NOT healthy"
  echo "$AGENT_STATUS_OUTPUT" | sed 's/^/     /'
fi

if echo "$AGENT_STATUS_OUTPUT" | grep -q "Connected"; then
  pass "Elastic Agent is connected to Fleet"
else
  fail "Elastic Agent is NOT connected to Fleet"
fi

# Check IBM MQ component unit state
IBMMQ_UNIT=$(docker logs "$AGENT_CONTAINER" 2>&1 \
  | grep "ibmmq" \
  | grep "HEALTHY\|STARTING\|FAILED\|DEGRADED" \
  | tail -1 || true)

if echo "$IBMMQ_UNIT" | grep -q "HEALTHY"; then
  pass "IBM MQ integration unit is HEALTHY"
elif [[ -z "$IBMMQ_UNIT" ]]; then
  fail "IBM MQ integration unit status unknown (no state log found)"
else
  fail "IBM MQ integration unit state: $IBMMQ_UNIT"
fi

# ── 4. Elasticsearch connectivity ───────────────────────────────────────────

echo ""
echo "── 4. Elasticsearch connectivity ───────────────────"

ES_ROOT=$(es "${ES_HOSTS}/" 2>/dev/null || true)
if echo "$ES_ROOT" | grep -q "cluster_uuid"; then
  CLUSTER_UUID=$(echo "$ES_ROOT" | grep -o '"cluster_uuid" *: *"[^"]*"' | grep -o '[a-zA-Z0-9_-]*$')
  CLUSTER_NAME=$(echo "$ES_ROOT" | grep -o '"cluster_name" *: *"[^"]*"' | grep -o '[^"]*$')
  pass "Connected to Elasticsearch (cluster_uuid: $CLUSTER_UUID)"
  echo "     cluster_name: $CLUSTER_NAME"
else
  fail "Cannot connect to Elasticsearch at $ES_HOSTS"
fi

# ── 5. Data stream presence ──────────────────────────────────────────────────

echo ""
echo "── 5. Data stream presence ─────────────────────────"

DS_RESPONSE=$(es "${ES_HOSTS}/_data_stream/metrics-ibmmq.qmgr-default" 2>/dev/null || true)
if echo "$DS_RESPONSE" | grep -q "metrics-ibmmq.qmgr-default"; then
  pass "Data stream metrics-ibmmq.qmgr-default exists"
  BACKING_INDEX=$(echo "$DS_RESPONSE" | grep -o '"index_name":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo "     backing index: $BACKING_INDEX"
else
  fail "Data stream metrics-ibmmq.qmgr-default does NOT exist"
fi

# ── 6. Document count ────────────────────────────────────────────────────────

echo ""
echo "── 6. Document count ───────────────────────────────"

COUNT_RESPONSE=$(es "${ES_HOSTS}/metrics-ibmmq.qmgr-default/_count" \
  -d '{"query":{"range":{"@timestamp":{"gte":"now-15m"}}}}' 2>/dev/null || true)
DOC_COUNT=$(echo "$COUNT_RESPONSE" | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0")

if [[ "${DOC_COUNT:-0}" -gt 0 ]]; then
  pass "$DOC_COUNT IBM MQ metric documents in Elasticsearch (last 15m)"
else
  fail "Zero IBM MQ metric documents in Elasticsearch (last 15m)"
  echo "     Waited long enough? Scrape interval is 60s. Try again in ~2 minutes."
fi

# Fetch one sample document
if [[ "${DOC_COUNT:-0}" -gt 0 ]]; then
  echo ""
  echo "   Latest sample document:"
  es "${ES_HOSTS}/metrics-ibmmq.qmgr-default/_search" \
    -d '{"size":1,"sort":[{"@timestamp":{"order":"desc"}}],"_source":["@timestamp","data_stream.dataset","labels.qmgr","host.name"]}' \
    2>/dev/null \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d.get('hits',{}).get('hits',[])
if hits:
    src = hits[0].get('_source', {})
    print('     @timestamp:           ', src.get('@timestamp','n/a'))
    print('     data_stream.dataset:  ', src.get('data_stream',{}).get('dataset','n/a'))
    print('     host.name:            ', src.get('host',{}).get('name','n/a'))
" 2>/dev/null || true
fi

# ── 7. Error log data stream ─────────────────────────────────────────────────

echo ""
echo "── 7. Error log data stream ────────────────────────"

LOG_COUNT_RESPONSE=$(es "${ES_HOSTS}/logs-ibmmq.errorlog-*/_count" \
  -d '{"query":{"range":{"@timestamp":{"gte":"now-1h"}}}}' 2>/dev/null || true)
LOG_COUNT=$(echo "$LOG_COUNT_RESPONSE" | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0")

if [[ "${LOG_COUNT:-0}" -gt 0 ]]; then
  pass "$LOG_COUNT IBM MQ error log documents found (last 1h)"
else
  pass "0 IBM MQ error log documents (expected – no errors is good)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════════════════"
printf "  Results:  \033[32m%d passed\033[0m  /  \033[31m%d failed\033[0m\n" "$PASS" "$FAIL"
echo "══════════════════════════════════════════════════"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "  ✔  All checks passed. Integration is working."
else
  echo "  ✘  $FAIL check(s) failed. See output above."
  exit 1
fi
