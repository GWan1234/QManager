#!/bin/sh
# test_failover.sh — Temporary safety net for band locking testing
# Pings 8.8.8.8 every 5s. On 3 consecutive failures, waits 30s then
# resets all bands to 1:3:41 so Tailscale access is preserved.
#
# Upload to modem:  scp test_failover.sh root@<ip>:/tmp/
# Run:              chmod +x /tmp/test_failover.sh && setsid /tmp/test_failover.sh &
# Stop:             kill $(cat /tmp/test_failover.pid)

echo $$ > /tmp/test_failover.pid
trap 'rm -f /tmp/test_failover.pid; exit 0' EXIT INT TERM

SAFE_BANDS="1:3:41"
FAIL_COUNT=0
FAIL_THRESHOLD=3
RESET_DELAY=60

echo "[test_failover] Started (PID=$$), monitoring connectivity..."

while true; do
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        FAIL_COUNT=0
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "[test_failover] Ping failed ($FAIL_COUNT/$FAIL_THRESHOLD)"
    fi

    if [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then
        echo "[test_failover] Connection lost! Waiting ${RESET_DELAY}s before reset..."
        sleep "$RESET_DELAY"

        echo "[test_failover] Resetting LTE bands to $SAFE_BANDS"
        qcmd "AT+QNWPREFCFG=\"lte_band\",${SAFE_BANDS}" 2>/dev/null

        echo "[test_failover] Bands reset. Exiting."
        exit 0
    fi

    sleep 5
done
