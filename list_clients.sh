#!/bin/bash

# Directory containing client configurations
CLIENTS_DIR="/home/felipe/VPN/clients"

# Check if the clients directory exists
if [ ! -d "$CLIENTS_DIR" ]; then
    echo "Error: Clients directory not found at $CLIENTS_DIR"
    exit 1
fi

# Count the number of clients
CLIENT_COUNT=$(ls -1 "$CLIENTS_DIR" | wc -l)

if [ "$CLIENT_COUNT" -eq 0 ]; then
    echo "No clients have been configured yet."
    echo "Use './add_client.sh client_name' to add a client."
    exit 0
fi

echo "WireGuard VPN Clients ($CLIENT_COUNT total):"
echo "----------------------------------------"

# Check if WireGuard is running
if ip link show wg0 &>/dev/null; then
    WG_RUNNING=true
    # Get current connection information
    WG_INFO=$(sudo wg show wg0)
else
    WG_RUNNING=false
fi

# List each client with its details
for CLIENT in $(ls -1 "$CLIENTS_DIR"); do
    echo "Client: $CLIENT"
    
    # Get client public key
    CLIENT_PUBLIC_KEY=$(cat "$CLIENTS_DIR/$CLIENT/public.key" 2>/dev/null)
    if [ -n "$CLIENT_PUBLIC_KEY" ]; then
        echo "  Public Key: $CLIENT_PUBLIC_KEY"
    fi
    
    # Get client IP from config file
    if [ -f "$CLIENTS_DIR/$CLIENT/$CLIENT.conf" ]; then
        CLIENT_IP=$(grep "Address" "$CLIENTS_DIR/$CLIENT/$CLIENT.conf" | cut -d= -f2 | tr -d ' ')
        echo "  IP Address: $CLIENT_IP"
    fi
    
    # Check if client is currently connected (if WireGuard is running)
    if [ "$WG_RUNNING" = true ] && [ -n "$CLIENT_PUBLIC_KEY" ]; then
        if echo "$WG_INFO" | grep -q "$CLIENT_PUBLIC_KEY"; then
            LAST_HANDSHAKE=$(echo "$WG_INFO" | grep -A2 "$CLIENT_PUBLIC_KEY" | grep "latest handshake" | sed 's/.*latest handshake: //')
            TRANSFER=$(echo "$WG_INFO" | grep -A3 "$CLIENT_PUBLIC_KEY" | grep "transfer" | sed 's/.*transfer: //')
            
            if [ -n "$LAST_HANDSHAKE" ]; then
                echo "  Status: Connected (Last handshake: $LAST_HANDSHAKE)"
                if [ -n "$TRANSFER" ]; then
                    echo "  Data Transfer: $TRANSFER"
                fi
            else
                echo "  Status: Configured but not connected"
            fi
        else
            echo "  Status: Configured but not connected"
        fi
    else
        echo "  Status: Unknown (WireGuard not running)"
    fi
    
    echo "  Config File: $CLIENTS_DIR/$CLIENT/$CLIENT.conf"
    echo "  QR Code: $CLIENTS_DIR/$CLIENT/$CLIENT.png"
    echo "----------------------------------------"
done

if [ "$WG_RUNNING" = false ]; then
    echo "Note: WireGuard is not currently running. Start it with 'sudo ./manage_wireguard.sh start'"
fi
