#!/bin/bash
set -a
source .env
set +a

OFFSET=0
mining_pid=""

send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="Markdown" >/dev/null
}

start_mining() {
  if [ -n "$mining_pid" ] && kill -0 $mining_pid 2>/dev/null; then
    send_telegram "⚠️ Mining already running!"
    return
  fi
  send_telegram "🚀 Starting mining..."
  netrum-mining &
  mining_pid=$!
}

stop_mining() {
  if [ -n "$mining_pid" ]; then
    kill $mining_pid 2>/dev/null
    send_telegram "🛑 Mining stopped!"
    mining_pid=""
  fi
}

check_balance() {
  BAL=$(node get-npt-balance.js 2>/dev/null)
  send_telegram "💰 Current Balance: ${BAL} NPT"
}

while true; do
  UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET")
  for row in $(echo "$UPDATES" | jq -c '.result[]'); do
    OFFSET=$(echo "$row" | jq '.update_id')+1
    TEXT=$(echo "$row" | jq -r '.message.text')
    
    case "$TEXT" in
      "/start")
        start_mining
        ;;
      "/stop")
        stop_mining
        ;;
      "/check")
        check_balance
        ;;
      *)
        send_telegram "❓ Unknown command: $TEXT"
        ;;
    esac
  done
  sleep 5
done
