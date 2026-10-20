#!/usr/bin/env bash
# Thin wrapper around the Dokploy API (tRPC-style endpoints).
#
# Usage:
#   scripts/api.sh project.all
#   scripts/api.sh application.one applicationId=<id>
#   scripts/api.sh application.deploy '{"applicationId":"<id>"}'
#
# GET when args are key=value query params (or none); POST when given JSON.
# Reads DOKPLOY_URL and DOKPLOY_API_KEY from the environment or ./.env.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f .env ]]; then set -a; source .env; set +a; fi
: "${DOKPLOY_URL:?set DOKPLOY_URL}" "${DOKPLOY_API_KEY:?set DOKPLOY_API_KEY}"

endpoint="${1:?usage: api.sh <endpoint> [k=v ...|json]}"; shift || true
if [[ $# -gt 0 && $1 == \{* ]]; then
  curl -s --fail-with-body -X POST \
    -H "x-api-key: $DOKPLOY_API_KEY" -H "Content-Type: application/json" \
    "$DOKPLOY_URL/api/$endpoint" -d "$1"
else
  query=""; for kv in "$@"; do query="${query:+$query&}$kv"; done
  curl -s --fail-with-body -H "x-api-key: $DOKPLOY_API_KEY" \
    "$DOKPLOY_URL/api/$endpoint${query:+?$query}"
fi
echo
