#!/bin/bash
# Vwarp Inline Installer

set -e

REPO="voidr3aper-anon/Vwarp"

echo "➔ Detecting system architecture..."
ARCH=$(uname -m)
case $ARCH in
    x86_64) BIN_ARCH="amd64" ;;
    aarch64|arm64) BIN_ARCH="arm64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "➔ Fetching latest release version..."
# Fetch the latest release tag from GitHub API
LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

# Fallback in case of GitHub API rate limiting
if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG=$(curl -sL -o /dev/null -w %{url_effective} "https://github.com/$REPO/releases/latest" | rev | cut -d/ -f1 | rev)
fi

if [ -z "$LATEST_TAG" ]; then
    echo "❌ Failed to fetch latest release."
    exit 1
fi

FILENAME="vwarp_linux-${BIN_ARCH}.zip"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$LATEST_TAG/$FILENAME"

echo "➔ Downloading Vwarp $LATEST_TAG for linux-${BIN_ARCH}..."
curl -sL -o /tmp/$FILENAME "$DOWNLOAD_URL"

echo "➔ Ensuring 'unzip' is installed..."
if ! command -v unzip &> /dev/null; then
    apt-get update -yqq && apt-get install unzip -yqq >/dev/null 2>&1 || true
fi

echo "➔ Extracting Vwarp..."
mkdir -p /tmp/vwarp_ext
unzip -o /tmp/$FILENAME -d /tmp/vwarp_ext >/dev/null

echo "➔ Installing binary to /opt/vwarp..."
sudo cp /tmp/vwarp_ext/vwarp /opt/vwarp
sudo chmod +x /opt/vwarp

echo "➔ Setting up systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/vwarp.service > /dev/null
[Unit]
Description=vwarp proxy service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/vwarp --scan
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

echo "➔ Starting Vwarp service..."
sudo systemctl daemon-reload
sudo systemctl enable vwarp
sudo systemctl restart vwarp

echo "➔ Cleaning up..."
rm -rf /tmp/$FILENAME /tmp/vwarp_ext

echo "✅ Vwarp installed and running successfully!"
echo "   Check logs using: sudo journalctl -u vwarp -f"
