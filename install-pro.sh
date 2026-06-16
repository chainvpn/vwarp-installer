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
    
    echo "----------------------------------------------------------------------"
    echo -e "Instance\tPort\tMode\t\tStatus\t\tOutbound IP"
    echo "----------------------------------------------------------------------"
    
    for service_file in /etc/systemd/system/vwarp*.service; do
        local s_name=$(basename "$service_file")
        local inst_num=$(echo "$s_name" | sed 's/[^0-9]//g')
        
        if [ -z "$inst_num" ] || [ ! -f "$service_file" ]; then continue; fi
        
        # Read the full ExecStart line safely
        local exec_line=$(grep -e "ExecStart=" "$service_file" || true)
        
        # Extract the --bind parameter safely using sed
        local bind_info=$(echo "$exec_line" | sed -n 's/.*--bind \([^ ]*\).*/\1/p')
        local b_port=$(echo "$bind_info" | cut -d: -f2)
        
        # Determine Mode (Using native Bash matching to prevent grep flag errors)
        local mode_str="Local"
        if [[ "$exec_line" == *"--cfon"* ]]; then
            local c_code=$(echo "$exec_line" | sed -n 's/.*--country \([^ ]*\).*/\1/p')
            mode_str="CFON ($c_code)"
        fi
        
        # Check systemd status
        if systemctl is-active --quiet "$s_name"; then
            local status_msg="RUNNING"
            # Test external IP via SOCKS5 proxy (5s timeout)
            local exit_ip=$(curl --connect-timeout 5 -s --socks5-hostname "127.0.0.1:$b_port" https://ifconfig.io || echo "TIMEOUT/FAILED")
            echo -e "vwarp$inst_num\t$b_port\t$mode_str\t$status_msg\t$exit_ip"
        else
            echo -e "vwarp$inst_num\t$b_port\t$mode_str\tSTOPPED\t---"
        fi
    done
    echo "================================================================------"
}

# --- 1. System Detection ---
EXISTING_COUNT=$(( $(ls /etc/systemd/system/vwarp*.service 2>/dev/null | wc -l) ))

if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo "▶ Detected $EXISTING_COUNT existing Vwarp instance(s) on this system."
    echo "1) Fresh Install / Reconfigure Everything"
    echo "2) Test current instances (Check Outbound IPs)"
    echo "3) Exit"
    read -p "Select an option [1-3]: " MENU_CHOICE
    
    case $MENU_CHOICE in
        2) test_instances; exit 0 ;;
        3) echo "Exiting."; exit 0 ;;
        1) echo "➔ Preparing for reconfiguration..." ;;
        *) echo "❌ Invalid choice. Exiting."; exit 1 ;;
    esac
fi

# --- 2. Step-by-Step Configuration Flow ---
echo ""
echo "--- Step 1: Choose Deployment Mode ---"
echo "1) Local Instances (Uses '--scan' configuration, NO custom countries)"
echo "2) Different Countries (Uses '--scan --cfon --country' rotating selection)"
echo "3) All Countries (Deploys one instance per country in the list)"
read -p "Select deployment mode [1-3]: " PROXY_MODE

NUM_COUNTRIES=${#COUNTRIES[@]}
INSTANCE_COUNT=0

case $PROXY_MODE in
    1)
        read -p "How many Local instances do you want to build? (e.g., 10): " INSTANCE_COUNT
        ;;
    2)
        read -p "How many Country instances do you want to build? (e.g., 10): " INSTANCE_COUNT
        ;;
    3)
        INSTANCE_COUNT=$NUM_COUNTRIES
        echo "➔ Mode 'All' selected. Will generate exactly $NUM_COUNTRIES instances."
        ;;
    *)
        echo "❌ Invalid proxy mode selection. Exiting."
        exit 1
        ;;
esac

if ! [[ "$INSTANCE_COUNT" =~ ^[0-9]+$ ]] || [ "$INSTANCE_COUNT" -le 0 ]; then
    echo "❌ Invalid number of instances. Exiting."
    exit 1
fi

echo ""
echo "--- Step 2: Define Network Bind Target ---"
read -p "Enter local Bind IP address (Default: 127.0.0.1, use 0.0.0.0 to expose publicly): " BIND_IP
if [ -z "$BIND_IP" ]; then
    BIND_IP="127.0.0.1"
fi

echo "➔ Strategy Verified: $INSTANCE_COUNT instance(s) binding to $BIND_IP"

# --- 3. Architecture Verification & Download Binary ---
echo ""
echo "--- Step 3: Fetching Engine Components ---"
echo "➔ Detecting system architecture..."
ARCH=$(uname -m)
case $ARCH in
    x86_64) BIN_ARCH="amd64" ;;
    aarch64|arm64) BIN_ARCH="arm64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "➔ Fetching latest release version from GitHub..."
LATEST_TAG=$(curl --connect-timeout 8 --max-time 15 -s "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' || true)

if [ -z "$LATEST_TAG" ]; then
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

# Locate the extracted binary (may be nested in a subdirectory)
EXTRACTED_BIN=$(find /tmp/vwarp_ext -type f -name "vwarp" | head -1)
if [ -z "$EXTRACTED_BIN" ]; then
    echo "❌ Could not locate 'vwarp' binary after extraction."
    exit 1
fi

# --- 4. Purge Previous Footprints ---
if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo "➔ Purging old services and executables..."
    for old_service in /etc/systemd/system/vwarp*.service; do
        if [ -f "$old_service" ]; then
            sudo systemctl stop "$(basename "$old_service")" >/dev/null 2>&1 || true
            sudo systemctl disable "$(basename "$old_service")" >/dev/null 2>&1 || true
            sudo rm -f "$old_service"
        fi
    done
    sudo rm -f /opt/vwarp[0-9]*
fi

# --- 5. Instance Generation Loop ---
echo ""
echo "--- Step 4: Generating Proxy Fleet ---"
for (( i=1; i<=INSTANCE_COUNT; i++ )); do
    PORT=$((BASE_PORT + i - 1))
    BIN_PATH="/opt/vwarp$i"
    SERVICE_NAME="vwarp$i.service"
    
    sudo cp "$EXTRACTED_BIN" "$BIN_PATH"
    sudo chmod +x "$BIN_PATH"
    
    # Generate ExecStart command based on the selected Mode
    if [ "$PROXY_MODE" -eq 1 ]; then
        # Mode 1: Local --scan deployment
        EXEC_CMD="$BIN_PATH --bind $BIND_IP:$PORT --scan"
        echo "   -> Setting up Local Instance $i | Port: $PORT (--scan)"
    else
        # Mode 2 & 3: Country deployment using BOTH --scan and --cfon
        COUNTRY_INDEX=$(( (i - 1) % NUM_COUNTRIES ))
        COUNTRY_CODE=${COUNTRIES[$COUNTRY_INDEX]}
        EXEC_CMD="$BIN_PATH --bind $BIND_IP:$PORT --scan --cfon --country $COUNTRY_CODE"
        echo "   -> Setting up Country Instance $i | Port: $PORT | Country: $COUNTRY_CODE"
    fi
    
    # Write structural service file
    cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null
[Unit]
Description=vwarp proxy service instance $i
After=network.target

[Service]
Type=simple
User=root
ExecStart=$EXEC_CMD
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable $SERVICE_NAME > /dev/null 2>&1
done

echo "➔ Reloading systemd structure and initializing connections..."
sudo systemctl daemon-reload

sleep 2  # Allow daemon-reload to fully settle before starting services

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

# --- 6. Automated Status/IP Testing Matrix ---
echo "➔ Pausing 5 seconds for proxy initialization..."
sleep 5
test_instances
