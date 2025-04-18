#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [start|stop|restart|status]"
    exit 1
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Check if command is provided
if [ -z "$1" ]; then
    usage
fi

CONFIG_FILE="/home/felipe/VPN/config/wg0.conf"

case "$1" in
    start)
        echo "Starting WireGuard VPN server..."
        wg-quick up ${CONFIG_FILE}
        ;;
    stop)
        echo "Stopping WireGuard VPN server..."
        wg-quick down ${CONFIG_FILE}
        ;;
    restart)
        echo "Restarting WireGuard VPN server..."
        wg-quick down ${CONFIG_FILE} 2>/dev/null || true
        wg-quick up ${CONFIG_FILE}
        ;;
    status)
        echo "WireGuard VPN server status:"
        wg show
        ;;
    *)
        usage
        ;;
esac

exit 0
