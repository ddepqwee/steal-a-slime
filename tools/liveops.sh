#!/usr/bin/env bash
# Мгновенно меняет параметры игры на всех живых серверах (без перепубликации).
# Нужен ключ Open Cloud с правом universe-messaging-service:publish.
#
# Примеры:
#   ./tools/liveops.sh '{"luck":3}'                                  # удача x3
#   ./tools/liveops.sh '{"cash":2,"announce":"x2 деньги на выходных!"}'
#   ./tools/liveops.sh "{\"event\":\"HALLOWEEN\",\"eventEnds\":$(($(date +%s)+3600))}"
set -euo pipefail
: "${ROBLOX_API_KEY:?нужен ROBLOX_API_KEY}"
: "${UNIVERSE_ID:?нужен UNIVERSE_ID}"
PAYLOAD="${1:?передай JSON}"

body=$(python3 -c 'import json,sys; print(json.dumps({"message": sys.argv[1]}))' "$PAYLOAD")
curl -sS -X POST \
  "https://apis.roblox.com/messaging-service/v1/universes/${UNIVERSE_ID}/topics/LiveOps" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$body"
echo "отправлено: $PAYLOAD"
