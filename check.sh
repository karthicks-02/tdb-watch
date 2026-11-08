#!/bin/bash
# Read-only: checks if Sabarimala room-booking season is open on onlinetdb.com. Never books.
set -u
TOK=$(curl -s -m 30 -X POST https://onlinetdb.com/TDB/login -H 'Content-Type: application/json' \
  -H "x-username: $TDB_USER" -H "x-password: $TDB_PASS" -d '{}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["userData"]["token"])' 2>/dev/null) || true
if [ -z "${TOK:-}" ]; then echo "Login failed"; exit 1; fi
RES=$(curl -s -m 30 -H "x-auth-token: $TOK" "https://onlinetdb.com/TDB/seasonmaster/fetchdate?projectId=1")
curl -s -m 15 -X POST https://onlinetdb.com/TDB/logout -H "x-auth-token: $TOK" -o /dev/null || true
echo "API response: $RES"
DATA=$(echo "$RES" | python3 -c 'import sys,json;d=json.load(sys.stdin).get("data");print("" if d is None else json.dumps(d))')
if [ -z "$DATA" ]; then
  echo "Season not open"
  [ "${SEND_TEST:-}" = "true" ] && curl -s -H "Title: TDB watch test" -d "Checker works. Season still NOT open." "https://ntfy.sh/$NTFY_TOPIC" >/dev/null
  exit 0
fi
echo "SEASON OPEN: $DATA"
curl -s -H "Title: Sabarimala rooms OPEN" -H "Priority: urgent" -H "Tags: rotating_light" \
  -H "Click: https://www.onlinetdb.com/tdbweb/dist/login" \
  -d "Room booking season is OPEN on onlinetdb.com. Book 27 Nov now! $DATA" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null
