#!/bin/bash
# Xray watchdog - restarts Xray if it's not running
if ! systemctl is-active --quiet xray; then
    systemctl restart xray
fi
