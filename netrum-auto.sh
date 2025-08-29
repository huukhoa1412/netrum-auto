#!/bin/bash

# Load .env
set -a
source .env
set +a

LOCKFILE="/tmp/netrum-auto.lock"
OFFSET=0
mining_pid=""
last_claim_time=$(date +%s)

# === Functions ===
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

send_telegram "📢 *Netrum Bot started!*"

# === Main Loop ===
while true; do
  # 1. Check new Telegram messages
  UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET")
  for row in $(echo "$UPDATES" | jq -c '.result[]'); do
    OFFSET=$(echo "$row" | jq '.update_id')+1
    TEXT=$(echo "$row" | jq -r '.message.text')

    case "$TEXT" in
      "/start") start_mining ;;
      "/stop") stop_mining ;;
      "/check") check_balance ;;
      "/wallet") send_telegram "💳 Wallet: \`${WALLET}\`" ;;
      "/status") show_status ;;
      *) send_telegram "❓ Unknown command: $TEXT" ;;
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
