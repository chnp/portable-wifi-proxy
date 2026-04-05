#!/bin/bash
# UPnP automatic port mapping for Xray
PORT=8443

# Remove old mapping
upnpc -d $PORT TCP 2>/dev/null

# Add new mapping (valid for 24 hours)
LOCAL_IP=$(hostname -I | awk '{print $1}')
upnpc -a "$LOCAL_IP" $PORT $PORT TCP 86400
