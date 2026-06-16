#!/bin/bash
# Vwarp Multi-Instance Auto-Installer

set -e

REPO="voidr3aper-anon/Vwarp"
COUNTRIES=(US CA BR GB DE FR IT ES NL SE NO DK FI CH AT BE IE PT PL CZ HU RO BG HR EE LV SK RS JP SG AU IN)
BASE_PORT=1086

echo "=================================================="
echo "          Vwarp Multi-Instance Installer          "
echo "=================================================="

# --- 1. Prompt User First ---
read -p "How many SOCKS 5 proxies do you want? (Enter a number, or type 'All' for all countries): " USER_INPUT

NUM_COUNTRIES=${#COUNTRIES[@]}

if [[ "${USER_INPUT,,}" == "all" ]]; then
    INSTANCE_COUNT=$NUM_COUNTRIES
elif [[ "$USER_INPUT" =~ ^[0-9]+$ ]] && [ "$USER_INPUT" -gt 0 ]; then
    INSTANCE_COUNT=$USER_INPUT
else
    echo "❌ Invalid input. Please run the script again and enter a valid integer or 'All'."
    exit 1
fi

echo "➔ Preparing to install $INSTANCE_COUNT instance(s)..."

# --- 2. System Architecture & Download ---
echo "➔ Detecting system architecture..."
ARCH=$(uname -m)
case $ARCH in
    x86_64) BIN_ARCH="amd64" ;;
    aarch64|arm64) BIN_ARCH="arm64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "➔ Fetching latest release version..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

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

echo "➔ Extracting core Vwarp binary..."
mkdir -p /tmp/vwarp_ext
unzip -o /tmp/$FILENAME -d /tmp/vwarp_ext >/dev/null

# --- 3. Multi-Instance Generation ---
echo "➔ Generating instances..."

for (( i=1; i<=INSTANCE_COUNT; i++ )); do
    # Calculate array index with modulo to wrap around if instances > number of countries
    COUNTRY_INDEX=$(( (i - 1) % NUM_COUNTRIES ))
    COUNTRY_CODE=${COUNTRIES[$COUNTRY_INDEX]}
    PORT=$((BASE_PORT + i - 1))
    
    BIN_PATH="/opt/vwarp$i"
    SERVICE_NAME="vwarp$i.service"
    
    echo "   -> Setting up Instance $i | Port: $PORT | Country: $COUNTRY_CODE"
    
    # Copy binary to unique path
    sudo cp /tmp/vwarp_ext/vwarp "$BIN_PATH"
    sudo chmod +x "$BIN_PATH"
    
    # Create unique systemd service file
    cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null
[Unit]
Description=vwarp proxy service instance $i ($COUNTRY_CODE)
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN_PATH --bind 127.0.0.1:$PORT --cfon --country $COUNTRY_CODE
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service quietly
    sudo systemctl enable $SERVICE_NAME > /dev/null 2>&1
done

# --- 4. Start Services & Cleanup ---
echo "➔ Reloading systemd and starting all instances..."
sudo systemctl daemon-reload

for (( i=1; i<=INSTANCE_COUNT; i++ )); do
    sudo systemctl restart "vwarp$i.service"
done

echo "➔ Cleaning up temporary files..."
rm -rf /tmp/$FILENAME /tmp/vwarp_ext

echo "=================================================="
echo "✅ Installation Complete!"
echo "   $INSTANCE_COUNT instance(s) are now running."
echo "   Ports range: 1086 to $((BASE_PORT + INSTANCE_COUNT - 1))"
echo "   To check a specific instance log, use: sudo journalctl -u vwarp1.service -f"
echo "=================================================="
