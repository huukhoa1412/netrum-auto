# netrum-auto
automatic mining, claim every 24h send notif telegram
## 📦 Requirements
- TELEGRAM_CHAT_ID & TELEGRAM_BOT_TOKEN
- Netrum Lite Node installed and running
- Linux environment (VPS, WSL on Windows
- 
1. Clone
   ```
   git clone https://github.com/huukhoa1412/netrum-auto.git
   cd netrum-auto
   ```
   
2. Config .env
   Change BOT_TOKEN, CHAT_ID, WALLET
   
   ```
   nano .env
   ```
   ## ⚙️ Setup
✅ Telegram BOT_TOKEN
- Create via [@BotFather](https://t.me/BotFather)
- Save the token (e.g., 123456789:ABCDEF...)

✅ Telegram CHAT_ID
- Send a message to your bot
- Use [@RawDataBot](https://t.me/RawDataBot) or
```
https://api.telegram.org/bot<your_token>/getUpdates
```

> ⚠️ Not supported on PowerShell/CMD. Use WSL or a Linux VPS.
> 
3. Permission & Dependencies
   ```
   chmod +x netrum-auto.sh
   npm install
   ```

4. Create Screen
   ```
   screen -S netrumauto
   ```
   
5. Run Script
   ```
   ./netrum-auto.sh
   ```

CTRL A + D for run in background

Join Our Telegram : [https://t.me/lehuukhoa]
