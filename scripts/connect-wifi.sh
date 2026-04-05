#!/bin/bash
# Connect to a WiFi network
# Usage: ./connect-wifi.sh "WiFi_Name" "WiFi_Password"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <SSID> <Password>"
    echo ""
    echo "Available WiFi networks:"
    nmcli dev wifi list
    exit 1
fi

SSID="$1"
PASSWORD="$2"

echo "Connecting to WiFi: $SSID ..."
nmcli dev wifi connect "$SSID" password "$PASSWORD"

if [ $? -eq 0 ]; then
    echo "Connected successfully!"
    echo "IP address:"
    hostname -I
else
    echo "Connection failed. Please check SSID and password."
fi
