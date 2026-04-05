#!/bin/bash
# Portable WiFi Proxy - One-click setup script
# Run on Debian/OpenStick (MSM8916) after flashing

set -e

echo "========================================="
echo "  Portable WiFi Proxy Setup"
echo "  VLESS + Reality + UPnP + DDNS"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_err() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [ "$EUID" -ne 0 ]; then
    print_err "Please run as root"
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Step 1: Fix apt sources
echo ""
echo ">>> Fixing apt sources..."
cp "$SCRIPT_DIR/config/sources.list" /etc/apt/sources.list
apt update -y
print_ok "Apt sources fixed"

# Step 2: Install dependencies
echo ""
echo ">>> Installing dependencies..."
apt install -y curl wget cron miniupnpc
print_ok "Dependencies installed"

# Step 3: Install Xray
echo ""
echo ">>> Installing Xray..."
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
print_ok "Xray installed"

# Step 4: Generate keys
echo ""
echo ">>> Generating keys..."
UUID=$(xray uuid)
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYS" | grep "PublicKey" | awk '{print $2}')

print_ok "UUID: $UUID"
print_ok "Private Key: $PRIVATE_KEY"
print_ok "Public Key: $PUBLIC_KEY"

# Step 5: Write Xray config
echo ""
echo ">>> Writing Xray config..."
sed -e "s/YOUR_UUID/$UUID/" -e "s|YOUR_PRIVATE_KEY|$PRIVATE_KEY|" \
    "$SCRIPT_DIR/config/xray-config.json" > /usr/local/etc/xray/config.json

xray run -test -config /usr/local/etc/xray/config.json
print_ok "Xray config written and validated"

# Step 6: Configure auto-restart
echo ""
echo ">>> Configuring auto-restart..."
mkdir -p /etc/systemd/system/xray.service.d
cp "$SCRIPT_DIR/config/restart.conf" /etc/systemd/system/xray.service.d/restart.conf
systemctl daemon-reload
systemctl enable xray
systemctl restart xray
print_ok "Xray enabled with auto-restart"

# Step 7: Install watchdog
echo ""
echo ">>> Installing watchdog..."
cp "$SCRIPT_DIR/scripts/xray-watchdog.sh" /usr/local/bin/
chmod +x /usr/local/bin/xray-watchdog.sh
(crontab -l 2>/dev/null | grep -v xray-watchdog; echo "* * * * * /usr/local/bin/xray-watchdog.sh") | crontab -
print_ok "Watchdog installed (checks every minute)"

# Step 8: Configure UPnP
echo ""
echo ">>> Configuring UPnP..."
cp "$SCRIPT_DIR/scripts/upnp-map.sh" /usr/local/bin/
chmod +x /usr/local/bin/upnp-map.sh
cp "$SCRIPT_DIR/config/upnp-map.service" /etc/systemd/system/
cp "$SCRIPT_DIR/config/upnp-map.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable upnp-map.service upnp-map.timer
print_ok "UPnP auto port mapping enabled"

# Step 9: Install WiFi connect helper
cp "$SCRIPT_DIR/scripts/connect-wifi.sh" /usr/local/bin/
chmod +x /usr/local/bin/connect-wifi.sh
print_ok "WiFi connect helper installed (use: connect-wifi.sh \"SSID\" \"password\")"

# Step 10: Add config backup alias
echo 'alias xedit="cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak && nano /usr/local/etc/xray/config.json"' >> ~/.bashrc
print_ok "Config backup alias added (use 'xedit' to safely edit config)"

# Step 11: Optional DDNS
echo ""
read -p "Configure Cloudflare DDNS? (y/n): " SETUP_DDNS
if [ "$SETUP_DDNS" = "y" ]; then
    read -p "Domain (e.g. wifi.example.com): " DDNS_DOMAIN
    read -p "Cloudflare Zone ID: " DDNS_ZONE_ID
    read -p "Cloudflare API Token: " DDNS_API_TOKEN

    # Create DNS record and get Record ID
    RECORD_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$DDNS_ZONE_ID/dns_records" \
      -H "Authorization: Bearer $DDNS_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$DDNS_DOMAIN\",\"content\":\"1.1.1.1\",\"ttl\":60,\"proxied\":false}")

    DDNS_RECORD_ID=$(echo "$RECORD_RESULT" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$DDNS_RECORD_ID" ]; then
        sed -e "s/YOUR_ZONE_ID/$DDNS_ZONE_ID/" \
            -e "s/YOUR_RECORD_ID/$DDNS_RECORD_ID/" \
            -e "s/YOUR_API_TOKEN/$DDNS_API_TOKEN/" \
            -e "s|wifi.yourdomain.com|$DDNS_DOMAIN|" \
            "$SCRIPT_DIR/scripts/ddns-update.sh" > /usr/local/bin/ddns-update.sh
        chmod +x /usr/local/bin/ddns-update.sh
        (crontab -l 2>/dev/null | grep -v ddns-update; echo "*/5 * * * * /usr/local/bin/ddns-update.sh") | crontab -
        /usr/local/bin/ddns-update.sh
        print_ok "DDNS configured for $DDNS_DOMAIN"
    else
        print_err "Failed to create DNS record. Please configure DDNS manually."
    fi
fi

# Done - print summary
echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "Your client configuration:"
echo ""
echo "  Protocol:    VLESS"
echo "  Port:        8443"
echo "  UUID:        $UUID"
echo "  Flow:        xtls-rprx-vision"
echo "  Transport:   tcp"
echo "  Security:    reality"
echo "  SNI:         www.microsoft.com"
echo "  Public Key:  $PUBLIC_KEY"
echo "  Short ID:    abcd1234"
echo ""
echo "Share link:"
echo "  vless://${UUID}@YOUR_IP_OR_DOMAIN:8443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=abcd1234&type=tcp#WiFi-US"
echo ""

# Generate QR code if qrencode is available
if command -v qrencode &>/dev/null; then
    echo "QR Code:"
    qrencode -t UTF8 "vless://${UUID}@YOUR_IP_OR_DOMAIN:8443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=abcd1234&type=tcp#WiFi-US"
else
    echo "Install qrencode for QR code: apt install -y qrencode"
fi

echo ""
echo "========================================="
echo "  Next Steps"
echo "========================================="
echo ""
echo "1. Bring device to the US"
echo "2. Plug into computer USB, SSH to 192.168.68.1"
echo "3. Run: connect-wifi.sh \"Your_WiFi_Name\" \"Your_WiFi_Password\""
echo "4. Unplug USB, connect power only — done!"
echo ""
echo "IMPORTANT: Save the UUID and Public Key above!"
echo "========================================="
