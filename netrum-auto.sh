#!/bin/bash

# Load .env
set -a
source .env
set +a

# ========== Telegram Function ==========
send_telegram() {
  local message="$1"
  local keyboard='{
    "inline_keyboard": [
      [
        {"text": "▶ Start", "callback_data": "/start"},
        {"text": "⏹ Stop", "callback_data": "/stop"}
      ],
      [
        {"text": "💰 Check Balance", "callback_data": "/check"},
        {"text": "💳 Wallet", "callback_data": "/wallet"},
        {"text": "⚡ Status", "callback_data": "/status"}
      ]
    ]
  }'
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="Markdown" \
    -d reply_markup="$keyboard" >/dev/null
}

# ========== Bot Actions ==========
start_mining() {
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    send_telegram "⚡ Mining already running ⛏️"
    return
  fi

  start_time=$(date '+%Y-%m-%d %H:%M:%S')
  NPT_BALANCE=$(node get-npt-balance.js 2>/dev/null)

  send_telegram "📢 *Netrum Report*  
*===== NETRUM AI =====*

🚀 *Mining started* ⛏️
🕒 *Start time*: $start_time
🧾 *Wallet*: \`${WALLET}\`
💰 *NPT Balance (Base)*: ${NPT_BALANCE} NPT"

  netrum-mining &
  mining_pid=$!

  (
    sleep 87000
    send_telegram "⏳ *24h completed. Claiming reward...* 🪙"
    echo "y" | netrum-claim
    kill $mining_pid 2>/dev/null
    send_telegram "✅ *Claim done! Restarting mining...* 🔁"
    start_mining
  ) &
}

stop_mining() {
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    kill $mining_pid
    mining_pid=""
    send_telegram "🛑 *Mining stopped*"
  else
    send_telegram "❌ Mining is not running"
  fi
}

check_balance() {
  NPT_BALANCE=$(node get-npt-balance.js 2>/dev/null)
  send_telegram "💰 *NPT Balance*: ${NPT_BALANCE} NPT"
}

show_status() {
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    send_telegram "⚡ Mining is *running* ⛏️ (PID: $mining_pid)"
  else
    send_telegram "🛑 Mining is *stopped*"
  fi
}

# ========== Main Loop ==========
OFFSET=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates" | jq '.result[-1].update_id' 2>/dev/null)
if [[ -z "$OFFSET" || "$OFFSET" == "null" ]]; then
  OFFSET=0
else
  OFFSET=$((OFFSET + 1))
fi

while true; do
  UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET")

  for row in $(echo "$UPDATES" | jq -c '.result[]?'); do
    update_id=$(echo "$row" | jq '.update_id')
    OFFSET=$((update_id + 1))

    # Text message
    TEXT=$(echo "$row" | jq -r '.message.text // empty')
    # Callback button
    CALLBACK=$(echo "$row" | jq -r '.callback_query.data // empty')

    COMMAND="$TEXT"
    if [[ -n "$CALLBACK" ]]; then
      COMMAND="$CALLBACK"
    fi

    case "$COMMAND" in
      "/start") start_mining ;;
      "/stop") stop_mining ;;
      "/check") check_balance ;;
      "/wallet") send_telegram "💳 Wallet: \`${WALLET}\`" ;;
      "/status") show_status ;;
    esac
  done

  sleep 3
done
