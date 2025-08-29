#!/bin/bash

# Load .env
set -a
source .env
set +a

LOCKFILE="/tmp/netrum-auto.lock"
mining_pid=""
last_claim_time=$(date +%s)

# === Functions ===
send_telegram() {
  local message="$1"
  local extra="$2" # optional JSON (reply_markup)
  if [ -z "$extra" ]; then
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
      -d chat_id="$CHAT_ID" \
      -d text="$message" \
      -d parse_mode="Markdown" >/dev/null
  else
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
      -d chat_id="$CHAT_ID" \
      -d text="$message" \
      -d parse_mode="Markdown" \
      -d reply_markup="$extra" >/dev/null
  fi
}

start_mining() {
  if [ -n "$mining_pid" ] && kill -0 $mining_pid 2>/dev/null; then
    send_telegram "⚠️ Mining already running!"
    return
  fi
  send_telegram "🚀 *Mining started* ⛏️"
  netrum-mining &
  mining_pid=$!
  last_claim_time=$(date +%s)
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

show_status() {
  if [ -n "$mining_pid" ] && kill -0 $mining_pid 2>/dev/null; then
    send_telegram "⚡ Mining is *running* ⛏️"
  else
    send_telegram "🛑 Mining is *stopped*"
  fi
}

# Cleanup on exit
cleanup() {
  stop_mining
  rm -f "$LOCKFILE"
}
trap cleanup EXIT INT TERM

# Prevent multiple instances
if [ -f "$LOCKFILE" ]; then
  echo "❌ Script already running!"
  exit 1
fi
touch "$LOCKFILE"

# === Skip old messages ===
OFFSET=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates" | jq '.result[-1].update_id + 1')
if [ "$OFFSET" = "null" ]; then
  OFFSET=0
fi

send_telegram "📢 *Netrum Bot started!*"

# === Inline keyboard menu JSON ===
INLINE_MENU='{
  "inline_keyboard": [
    [{"text": "🚀 Start", "callback_data": "/start"},
     {"text": "🛑 Stop", "callback_data": "/stop"}],
    [{"text": "⚡ Status", "callback_data": "/status"},
     {"text": "💰 Balance", "callback_data": "/check"}],
    [{"text": "💳 Wallet", "callback_data": "/wallet"}]
  ]
}'

# === Main Loop ===
while true; do
  # 1. Check new Telegram messages
  UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET")
  for row in $(echo "$UPDATES" | jq -c '.result[]'); do
    update_id=$(echo "$row" | jq '.update_id')
    OFFSET=$((update_id + 1))

    TEXT=$(echo "$row" | jq -r '.message.text')
    CALLBACK=$(echo "$row" | jq -r '.callback_query.data // empty')

    # Nếu là inline keyboard (callback)
    if [ -n "$CALLBACK" ] && [ "$CALLBACK" != "null" ]; then
      TEXT="$CALLBACK"
      # trả lời callback để Telegram không báo "loading..."
      callback_id=$(echo "$row" | jq -r '.callback_query.id')
      curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/answerCallbackQuery" \
        -d callback_query_id="$callback_id" >/dev/null
    fi

    case "$TEXT" in
      "/start") start_mining ;;
      "/stop") stop_mining ;;
      "/check") check_balance ;;
      "/wallet") send_telegram "💳 Wallet: \`${WALLET}\`" ;;
      "/status") show_status ;;
      "/menu") send_telegram "📋 *Choose an option:*" "$INLINE_MENU" ;;
      *) if [ -n "$TEXT" ] && [ "$TEXT" != "null" ]; then
           send_telegram "❓ Unknown command: $TEXT"
         fi
         ;;
    esac
  done

  # 2. Auto-claim every 24h
  now=$(date +%s)
  if [ -n "$mining_pid" ] && (( now - last_claim_time >= 86400 )); then
    send_telegram "⏳ *24h passed. Claiming reward...* 🪙"
    echo "y" | netrum-claim
    stop_mining
    start_mining
    send_telegram "✅ *Claim completed & mining restarted!* 🔁"
  fi

  sleep 5
done
