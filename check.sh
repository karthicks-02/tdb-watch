#!/bin/bash
# Read-only: checks if Sabarimala room-booking season is open on onlinetdb.com. Never books.
set -u
# Sends to every configured channel: ntfy (+email via ntfy), WhatsApp (CallMeBot).
notify() { # $1 title, $2 message, $3 priority
  local EH=(); [ -n "${EMAIL_TO:-}" ] && EH=(-H "Email: $EMAIL_TO")
  curl -s -m 20 -H "Title: $1" -H "Priority: $3" -H "Tags: rotating_light" \
    -H "Click: https://www.onlinetdb.com/tdbweb/dist/login" "${EH[@]}" -d "$2" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null && echo "ntfy sent"
  if [ -n "${WA_PHONE:-}" ] && [ -n "${WA_APIKEY:-}" ]; then
    curl -s -m 20 -G "https://api.callmebot.com/whatsapp.php" --data-urlencode "phone=$WA_PHONE" \
      --data-urlencode "text=*$1* - $2" --data-urlencode "apikey=$WA_APIKEY" >/dev/null && echo "whatsapp sent"
  fi
}
# Retries: each request up to 3 tries (5s apart, 20s timeout each); whole login+check up to 3 attempts.
C=(curl -s -m 20 --retry 2 --retry-delay 5 --retry-all-errors)
TOK=""; RES=""
for attempt in 1 2 3; do
  TOK=$("${C[@]}" -X POST https://onlinetdb.com/TDB/login -H 'Content-Type: application/json' \
    -H "x-username: $TDB_USER" -H "x-password: $TDB_PASS" -d '{}' \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["userData"]["token"])' 2>/dev/null) || true
  if [ -n "$TOK" ]; then
    RES=$("${C[@]}" -H "x-auth-token: $TOK" "https://onlinetdb.com/TDB/seasonmaster/fetchdate?projectId=1")
    curl -s -m 15 -X POST https://onlinetdb.com/TDB/logout -H "x-auth-token: $TOK" -o /dev/null || true
    echo "$RES" | python3 -c 'import sys,json;json.load(sys.stdin)["success"]' 2>/dev/null && break
    echo "Attempt $attempt: bad season response: ${RES:0:200}"
  else
    echo "Attempt $attempt: login failed"
  fi
  RES=""; sleep 10
done
if [ -z "$TOK" ]; then echo "Login failed after 3 attempts"; exit 1; fi
if [ -z "$RES" ]; then echo "Season API unreachable after 3 attempts - will try next run"; exit 0; fi
echo "API response: $RES"
DATA=$(echo "$RES" | python3 -c 'import sys,json;d=json.load(sys.stdin).get("data");print("" if d is None else json.dumps(d))')
if [ -z "$DATA" ]; then
  echo "Season not open"
  [ "${SEND_TEST:-}" = "true" ] && notify "TDB watch: running OK" "Status check $(TZ=Asia/Kolkata date +"%d %b %I:%M %p IST"): watcher is working. Sabarimala season still NOT open." high
  exit 0
fi
echo "SEASON OPEN: $DATA"
notify "Sabarimala rooms OPEN" "Room booking season is OPEN on onlinetdb.com. Book 27 Nov now! https://www.onlinetdb.com/tdbweb/dist/login" urgent
echo "::error title=SABARIMALA ROOMS OPEN::Room booking season is OPEN on onlinetdb.com - book 27 Nov now!"
exit 1  # deliberate failure => GitHub emails the account owner
