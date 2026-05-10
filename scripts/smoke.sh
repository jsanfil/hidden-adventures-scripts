#!/bin/sh

set -eu

BASE_URL="${BASE_URL:-https://hiddenadventures.lucidios.com}"

curl -fsS "$BASE_URL/api/health" >/dev/null
curl -fsS "$BASE_URL/public/privacy-policy.html" >/dev/null
curl -fsS "$BASE_URL/public/terms-conditions.html" >/dev/null

echo "Production smoke checks passed for $BASE_URL"
