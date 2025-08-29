#!/bin/bash

# Load .env (BOT_TOKEN, CHAT_ID, WALLET)
set -a
source .env
set +a

# Hàm gửi tin nhắn Telegram
send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message" \
    -d parse_mode="Markdown"
}

# Khởi tạo biến PID đào
mining_pid=""

# Hàm bắt đầu đào
start_mining() {
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    send_telegram "⚠️ Mining đã *chạy sẵn* rồi (PID: $mining_pid)"
  else
    netrum-mining &   # chạy nền
    mining_pid=$!
    send_telegram "🚀 *Mining bắt đầu* ⛏️ (PID: $mining_pid)"
  fi
}

# Hàm dừng đào
stop_mining() {
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    kill "$mining_pid"
    send_telegram "🛑 *Mining đã dừng* (PID: $mining_pid)"
    mining_pid=""
  else
    send_telegram "ℹ️ *Không có mining nào đang chạy*"
  fi
}

# Hàm kiểm tra số dư
check_balance() {
  NPT_BALANCE=$(node get-npt-balance.js 2>/dev/null)
  send_telegram "💰 *NPT Balance*: ${NPT_BALANCE} NPT"
}

# Hàm hiển thị ví
show_wallet() {
  send_telegram "💳 *Wallet*: \`${WALLET}\`"
}

# Hàm hiển thị status bằng netrum-mining-log
show_status() {
  if [[ -n "$mining_pid" && -e /proc/$mining_pid ]]; then
    LOG=$(netrum-mining-log 2>/dev/null)

    if echo "$LOG" | grep -q "Error fetching status"; then
      send_telegram "⚠️ *Mining Status*  

$LOG"
    else
      send_telegram "📡 *Mining Status*  

$LOG"
    fi
  else
    send_telegram "🛑 Mining is *stopped*"
  fi
}

# --- Xử lý Telegram Update ---
OFFSET=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates" | jq '.result[-1].update_id' 2>/dev/null)
if [[ -z "$OFFSET" || "$OFFSET" == "null" ]]; then
  OFFSET=0
else
  OFFSET=$((OFFSET + 1))
fi

send_telegram "🤖 *Netrum Bot khởi động thành công!*"

while true; do
  UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET")

  for row in $(echo "$UPDATES" | jq -c '.result[]?'); do
    update_id=$(echo "$row" | jq '.update_id')
    OFFSET=$((update_id + 1))
    TEXT=$(echo "$row" | jq -r '.message.text // empty')

    case "$TEXT" in
      "/start") start_mining ;;
      "/stop") stop_mining ;;
      "/check") check_balance ;;
      "/wallet") show_wallet ;;
      "/status") show_status ;;
    esac
  done

  sleep 2
done
