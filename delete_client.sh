#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Check if a client name was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <client_name>"
    echo "Example: $0 client1"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_DIR="/home/felipe/VPN/clients/${CLIENT_NAME}"
CONFIG_FILE="/home/felipe/VPN/config/wg0.conf"
BACKUP_DIR="/home/felipe/VPN/config/backups"
MAX_BACKUPS=5

# Create backups directory if it doesn't exist
sudo mkdir -p "$BACKUP_DIR"

# Check if the client exists
if [ ! -d "$CLIENT_DIR" ]; then
    echo "Error: Client '$CLIENT_NAME' does not exist."
    echo "Available clients:"
    ls -1 /home/felipe/VPN/clients/ 2>/dev/null || echo "No clients found."
    exit 1
fi

# Get client's public key
CLIENT_PUBLIC_KEY=$(cat "${CLIENT_DIR}/public.key" 2>/dev/null)
if [ -z "$CLIENT_PUBLIC_KEY" ]; then
    echo "Warning: Could not find public key for client '$CLIENT_NAME'."
    echo "Will attempt to remove based on client name in config file."
fi

echo "Removing client '$CLIENT_NAME' from WireGuard configuration..."

# Create a temporary file for the new configuration
TEMP_CONF=$(mktemp)

# Extract the interface section (everything before the first peer)
awk '/^\[Peer\]/{ exit } { print }' "$CONFIG_FILE" > "$TEMP_CONF"

# Find and keep all peer sections except the one we want to remove
awk -v client="$CLIENT_NAME" -v pubkey="$CLIENT_PUBLIC_KEY" '
    BEGIN { peer=0; skip=0; buffer="" }
    /^\[Peer\]/ {
        if (peer && !skip) { print buffer }
        peer=1; skip=0; buffer="[Peer]\n"; next
    }
    peer && /^# / && $0 ~ client { skip=1 }
    peer && /^PublicKey/ && $3 == pubkey { skip=1 }
    peer && !skip { buffer = buffer $0 "\n" }
    END { if (peer && !skip && buffer != "[Peer]\n") print buffer }
' "$CONFIG_FILE" >> "$TEMP_CONF"

# Check if any changes were made
if diff -q "$CONFIG_FILE" "$TEMP_CONF" >/dev/null; then
    echo "Warning: No changes were made to the configuration file."
    echo "Client '$CLIENT_NAME' may not be properly configured in $CONFIG_FILE."
    rm "$TEMP_CONF"
else
    # Backup the original config
    BACKUP_FILE="${BACKUP_DIR}/wg0.conf.bak.$(date +%Y%m%d%H%M%S)"
    sudo cp "$CONFIG_FILE" "$BACKUP_FILE"

    # Replace the config file with the new one
    sudo cp "$TEMP_CONF" "$CONFIG_FILE"
    rm "$TEMP_CONF"

    echo "Configuration updated. Original config backed up to $BACKUP_FILE"

    # Check if WireGuard is running and apply changes
    if ip link show wg0 &>/dev/null; then
        echo "Applying changes to the running WireGuard server..."
        sudo wg-quick down wg0
        sudo wg-quick up "$CONFIG_FILE"
        echo "WireGuard restarted with the updated configuration."
    else
        echo "WireGuard is not currently running. Changes will apply on next start."
    fi

    # Keep only the most recent backups
    echo "Managing backup files..."
    ls -t "${BACKUP_DIR}/wg0.conf.bak."* 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs sudo rm -f 2>/dev/null

    REMAINING_BACKUPS=$(ls -1 "${BACKUP_DIR}/wg0.conf.bak."* 2>/dev/null | wc -l)
    echo "Keeping $REMAINING_BACKUPS most recent backups in $BACKUP_DIR"
fi

# Remove the client directory
echo "Removing client files..."
sudo rm -rf "$CLIENT_DIR"
echo "Client '$CLIENT_NAME' has been removed."

# List remaining clients
REMAINING_CLIENTS=$(ls -1 /home/felipe/VPN/clients/ 2>/dev/null | wc -l)
if [ "$REMAINING_CLIENTS" -gt 0 ]; then
    echo "Remaining clients:"
    ls -1 /home/felipe/VPN/clients/
else
    echo "No clients remaining."
fi
