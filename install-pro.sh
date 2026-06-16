#!/bin/bash
# Vwarp Pro Manager & Multi-Instance Installer

set -e

REPO="voidr3aper-anon/Vwarp"
COUNTRIES=(US CA BR GB DE FR IT ES NL SE NO DK FI CH AT BE IE PT PL CZ HU RO BG HR EE LV SK RS JP SG AU IN)
BASE_PORT=1086

echo "=================================================="
echo "          Vwarp Pro Instance Manager              "
echo "=================================================="

# --- Function: Test Existing Instances ---
test_instances() {
    echo "➔ Running connection tests on active instances..."
    local active_services=$(ls /etc/systemd/system/vwarp*.service 2>/dev/null || true)
    
    if [ -z "$active_services" ]; then
        echo "❌ No active Vwarp instances found to test."
        return
    fi
    
    echo "--------------------------------------------------"
    echo -e "Instance\tPort\tStatus\t\tOutbound IP / Country"
    echo "--------------------------------------------------"
    
    for service_file in /etc/systemd/system/vwarp*.service; do
        local s_name=$(basename "$service_file")
        local inst_num=$(echo "$s_name" | grep -o -E '[0-9]+')
        
        # Extract port and bind IP from service file
        local bind_info=$(grep -oP '--bind \K[^ ]+' "$service_file" || true)
        if [ -z "$bind_info" ]; then continue; fi
        
        # Split IP and Port
        local b_ip=$(echo "$bind_info" | cut -d: -f1)
        local b_port=$(echo "$bind_info" | cut -d: -f2)
        
        # Check systemd status
        if systemctl is-active --quiet "$s_name"; then
            local status_msg="RUNNING"
            # Test external IP via SOCKS5 proxy (using 5s timeout)
            # Using --socks5-hostname so DNS resolves through the proxy safely
            local exit_ip=$(curl --connect-timeout 5 -s --socks5-hostname "127.0.0.1:$b_port" https://ifconfig.io || echo "TIMEOUT/FAILED")
            echo -e "vwarp$inst_num\t$b_port\t$status_msg\t$exit_ip"
        else
            echo -e "vwarp$inst_num\t$b_port\tSTOPPED\t\t---"
        fi
    done
    echo "=================================================="
}

# --- 1. Detection & Menu Option ---
EXISTING_COUNT=$(ls /etc/systemd/system/vwarp*.service 2>/dev/null | wc -l || echo 0)

if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo "▶ Detected $EXISTING_COUNT existing Vwarp instance(s) on this system."
    echo "1) Edit / Reconfigure / Fresh Install"
    echo "2) Test current instances (Check Outbound IPs)"
    echo "3) Exit"
    read -p "Select an option [1-3]: " MENU_CHOICE
    
    case $MENU_CHOICE in
        2) test_instances; exit 0 ;;
        3) echo "Exiting."; exit 0 ;;
        1) echo "➔ Proceeding to reconfigure setup..." ;;
        *) echo "❌ Invalid choice. Exiting."; exit 1 ;;
    esac
fi

# --- 2. Configuration Prompts ---
read -p "How many SOCKS 5 proxies do you want? (Enter a number, or type 'All' for all countries): " USER_INPUT

NUM_COUNTRIES=${#COUNTRIES[@]}
if [[ "${USER_INPUT,,}" == "all" ]]; then
    INSTANCE_COUNT=$NUM_COUNTRIES
elif [[ "$USER_INPUT" =~ ^[0-9]+$ ]] && [ "$USER_INPUT" -gt 0 ]; then
    INSTANCE_COUNT=$USER_INPUT
else
    echo "❌ Invalid input. Exiting."
    exit 1
fi

read -p "Enter local Bind IP address (Default: 127.0.0.1, use 0.0.0.0 to expose publicly): " BIND_IP
if [ -z "$BIND_IP" ]; then
    BIND_IP="127.0.0.1"
fi

echo "➔ Selected: $INSTANCE_COUNT instance(s) binding to $BIND_IP"

# --- 3. Architecture & Download ---
echo "➔ Detecting system architecture..."
ARCH=$(uname -m)
case $ARCH in
    x86_64) BIN_ARCH="amd64" ;;
    aarch64|arm64) BIN_ARCH="arm64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "➔ Fetching latest release version..."
LATEST_TAG=$(curl --connect-timeout 8 --max-time 15 -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' || true)

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "latest" ]; then
    LATEST_TAG=$(curl --connect-timeout 8 --max-time 15 -sL -o /dev/null -w %{url_effective} "https://github.com/$REPO/releases/latest" | rev | cut -d/ -f1 | rev || true)
fi

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "latest" ]; then
    echo "⚠️  GitHub API connection timed out."
    read -p "Please manually enter the Vwarp version tag (e.g., v2.2.2): " LATEST_TAG
fi

FILENAME="vwarp_linux-${BIN_ARCH}.zip"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$LATEST_TAG/$FILENAME"

echo "➔ Downloading Vwarp $LATEST_TAG..."
mkdir -p /tmp/vwarp_ext
if ! curl --connect-timeout 15 --max-time 60 -L -o /tmp/$FILENAME "$DOWNLOAD_URL"; then
    echo "❌ Download failed."
    exit 1
fi

echo "➔ Ensuring 'unzip' is installed..."
if ! command -v unzip &> /dev/null; then
    apt-get update -yqq && apt-get install unzip -yqq >/dev/null 2>&1 || true
fi

unzip -o /tmp/$FILENAME -d /tmp/vwarp_ext >/dev/null

# --- 4. Remove Old Configuration if Editing ---
if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo "➔ Cleaning up previous instances..."
    for old_service in /etc/systemd/system/vwarp*.service; do
        sudo systemctl stop "$(basename "$old_service")" >/dev/null 2>&1 || true
        sudo systemctl disable "$(basename "$old_service")" >/dev/null 2>&1 || true
        sudo rm -f "$old_service"
    done
    sudo rm -f /opt/vwarp[0-9]*
fi

# --- 5. Multi-Instance Generation ---
echo "➔ Building instances..."
for (( i=1; i<=INSTANCE_COUNT; i++ )); do
    COUNTRY_INDEX=$(( (i - 1) % NUM_COUNTRIES ))
    COUNTRY_CODE=${COUNTRIES[$COUNTRY_INDEX]}
    PORT=$((BASE_PORT + i - 1))
    
    BIN_PATH="/opt/vwarp$i"
    SERVICE_NAME="vwarp$i.service"
    
    sudo cp /tmp/vwarp_ext/vwarp "$BIN_PATH"
    sudo chmod +x "$BIN_PATH"
    
    cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null
[Unit]
Description=vwarp proxy service instance $i ($COUNTRY_CODE)
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN_PATH --bind $BIND_IP:$PORT --cfon --country $COUNTRY_CODE
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable $SERVICE_NAME > /dev/null 2>&1
done

echo "➔ Reloading systemd and starting new instances..."
sudo systemctl daemon-reload

for (( i=1; i<=INSTANCE_COUNT; i++ )); do
    sudo systemctl restart "vwarp$i.service"
done

rm -rf /tmp/$FILENAME /tmp/vwarp_ext

echo "=================================================="
echo "✅ Installation Complete!"
echo "   Deployed $INSTANCE_COUNT instances."
echo "   Ports: $BASE_PORT to $((BASE_PORT + INSTANCE_COUNT - 1))"
echo "=================================================="
echo ""

# --- 6. Post-Install Automatic Verification ---
echo "➔ Waiting 5 seconds for proxies to warm up before verification..."
sleep 5
test_instances
