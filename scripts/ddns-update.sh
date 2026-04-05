#!/bin/bash
# Cloudflare DDNS updater
# Fill in your own values below

ZONE_ID="YOUR_ZONE_ID"
RECORD_ID="YOUR_RECORD_ID"
API_TOKEN="YOUR_API_TOKEN"
DOMAIN="wifi.yourdomain.com"

IP=$(curl -s https://api.ipify.org)

if [ -n "$IP" ]; then
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$IP\",\"ttl\":60,\"proxied\":false}"
fi
