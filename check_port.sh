#!/bin/bash

PORT=443

echo "Checking if port $PORT is already in use..."

# Check if the port is in use
if ss -tuln | grep -q ":$PORT "; then
    echo "WARNING: Port $PORT is already in use by another service."
    echo "This may cause conflicts with WireGuard which is configured to use port $PORT."
    echo "Current services using port $PORT:"
    ss -tuln | grep ":$PORT "
    echo ""
    echo "Options:"
    echo "1. Change the WireGuard port in config/wg0.conf and add_client.sh"
    echo "2. Stop the service using port $PORT before starting WireGuard"
else
    echo "Port $PORT is available and not in use by any other service."
fi
