#!/bin/bash

# ========== Setup ==========
set -a
source .env
set +a

LOCK_FILE="/tmp/netrum-bot.lock"
PID_FILE="/tmp/netrum-mining.pid"

# Chỉ cho phép 1 instance chạy
exec 200>$LOCK_FILE
flock -n 200 || { echo "Another instance is running"; exit 1; }

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

# ========== PID Handling ==========
save_pid() { echo "$mining_pid" > "$PID_FILE"; }
load_pid() { [[ -f "$PID_FILE" ]] && mining_pid=$(cat "$PID_FILE"); }

# ========== Bot Actions ==========
start_mining() {
  load_pid
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    send_telegram "⚡ Mining already running ⛏️ (PID: $mining_pid)"
    return
  fi

  start_time=$(date '+%Y-%m-%d %H:%M:%S')
  NPT_BALANCE=$(node get-npt-balance.js 2>/dev/null)

  send_telegram "📢 *Netrum Report*  
🚀 *Mining started* ⛏️
🕒 *Start time*: $start_time
🧾 *Wallet*: \`${WALLET}\`
💰 *NPT Balance (Base)*: ${NPT_BALANCE} NPT"

  netrum-mining &
  mining_pid=$!
  save_pid

  (
    sleep 87000
    send_telegram "⏳ *24h completed. Claiming reward...* 🪙"
    echo "y" | netrum-claim
    kill $mining_pid 2>/dev/null
    rm -f "$PID_FILE"
    send_telegram "✅ *Claim done! Restarting mining...* 🔁"
    start_mining
  ) &
}

stop_mining() {
  load_pid
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    kill $mining_pid
    rm -f "$PID_FILE"
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
  load_pid
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    LOG=$(netrum-mining-log 2>/dev/null | tail -n 1)
    if [[ -z "$LOG" ]]; then
      LOG="Không có log mới."
    elif [[ "$LOG" == *"Error fetching status"* ]]; then
      LOG="❌ Mining chưa sẵn sàng. Vui lòng thử lại sau 5 phút."
    fi
    send_telegram "⚡ Mining is *running* ⛏️ (PID: $mining_pid)\n\n📄 *Current status:*\n\`\`\`\n$LOG\n\`\`\`"
  else
    send_telegram "🛑 Mining is *stopped*"
  fi
}

# ========== Main Loop ==========
OFFSET=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates" | jq '.result[-1].update_id' 2>/dev/null)
[[ -z "$OFFSET" || "$OFFSET" == "null" ]] && OFFSET=0 || OFFSET=$((OFFSET + 1))

while true; do
  UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET")

  jq -c '.result[]?' <<<"$UPDATES" | while read -r row; do
    update_id=$(echo "$row" | jq '.update_id')
    OFFSET=$((update_id + 1))

    TEXT=$(echo "$row" | jq -r '.message.text // empty')
    CALLBACK=$(echo "$row" | jq -r '.callback_query.data // empty')

    COMMAND="$TEXT"
    [[ -n "$CALLBACK" ]] && COMMAND="$CALLBACK"

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
