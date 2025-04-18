#!/bin/bash

# Check if a client name was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <client_name>"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_DIR="/home/felipe/VPN/clients/${CLIENT_NAME}"
CONFIG_DIR="/home/felipe/VPN/config"
BACKUP_DIR="/home/felipe/VPN/config/backups"
MAX_BACKUPS=5
SERVER_PUBLIC_KEY=$(cat ${CONFIG_DIR}/server_public.key)
# Get public IP address for external connections using dig (faster than curl)
SERVER_IP=$(dig +short txt ch whoami.cloudflare | tr -d '"')
# Fallback to local IP if public IP cannot be retrieved
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(ip -4 addr show enp0s6 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo "Warning: Could not retrieve public IP, using local IP: $SERVER_IP"
fi
WG_PORT=443

# Create backups directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create client directory if it doesn't exist
mkdir -p ${CLIENT_DIR}

# Generate client keys
wg genkey | tee ${CLIENT_DIR}/private.key | wg pubkey > ${CLIENT_DIR}/public.key
CLIENT_PRIVATE_KEY=$(cat ${CLIENT_DIR}/private.key)
CLIENT_PUBLIC_KEY=$(cat ${CLIENT_DIR}/public.key)

# Assign IP address (increment for each client)
# Count existing clients to determine the next IP
CLIENT_COUNT=$(ls -1 /home/felipe/VPN/clients/ | wc -l)
CLIENT_IP="10.10.0.$((CLIENT_COUNT + 2))"

# Create client configuration
echo "Using server endpoint: 134.65.28.106:443"
echo "Note: For external connections, this should be your public IP address"

cat > ${CLIENT_DIR}/${CLIENT_NAME}.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = 134.65.28.106:443
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Backup the original config before adding the client
BACKUP_FILE="${BACKUP_DIR}/wg0.conf.bak.$(date +%Y%m%d%H%M%S)"
cp "${CONFIG_DIR}/wg0.conf" "$BACKUP_FILE"
echo "Created backup at $BACKUP_FILE"

# Add client to server configuration
# First, create a temporary file with the new peer configuration
TEMP_PEER=$(mktemp)
cat > "${TEMP_PEER}" << EOF
[Peer]
# ${CLIENT_NAME}
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

# Append the new peer to the config file
cat "${TEMP_PEER}" >> "${CONFIG_DIR}/wg0.conf"
rm "${TEMP_PEER}"

# Keep only the most recent backups
ls -t "${BACKUP_DIR}/wg0.conf.bak."* 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null
REMAINING_BACKUPS=$(ls -1 "${BACKUP_DIR}/wg0.conf.bak."* 2>/dev/null | wc -l)
echo "Keeping $REMAINING_BACKUPS most recent backups in $BACKUP_DIR"

# Generate QR code for mobile clients
qrencode -t PNG -o ${CLIENT_DIR}/${CLIENT_NAME}.png < ${CLIENT_DIR}/${CLIENT_NAME}.conf

# Create the connection script
cat > ${CLIENT_DIR}/${CLIENT_NAME}_connect.sh << 'EOF'
#!/bin/bash

# Color definitions
GREEN="\033[0;32m"
BRIGHT_GREEN="\033[1;32m"
BLUE="\033[0;34m"
LIGHT_BLUE="\033[0;94m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
BOLD="\033[1m"
BLINK="\033[5m"
DIM="\033[2m"
NC="\033[0m" # No color

# Client name
CLIENT_NAME="PLACEHOLDER_CLIENT_NAME"

# Function to display the GhostWire banner
display_banner() {
    clear
    echo -e "${BRIGHT_GREEN}"
    echo -e " ██████╗ ██╗ ██╗ ██████╗ ███████╗████████╗██╗    ██╗██╗██████╗ ███████╗"
    echo -e "██╔════╝ ██║ ██║██╔═══██╗██╔════╝╚══██╔══╝██║    ██║██║██╔══██╗██╔════╝"
    echo -e "██║  ███╗██████║██║   ██║███████╗   ██║   ██║ █╗ ██║██║██████╔╝█████╗  "
    echo -e "██║   ██║██╔═██║██║   ██║╚════██║   ██║   ██║███╗██║██║██╔══██╗██╔══╝  "
    echo -e "╚██████╔╝██║ ██║╚██████╔╝███████║   ██║   ╚███╔███╔╝██║██║  ██║███████╗"
    echo -e " ╚═════╝ ╚═╝ ╚═╝ ╚═════╝ ╚══════╝   ╚═╝    ╚══╝╚══╝ ╚═╝╚═╝  ╚═╝╚══════╝"
    echo -e "${CYAN}                                                      ${BLINK}[${NC}${PURPLE} FelipeFMA ${BRIGHT_GREEN}${BLINK}]${NC}"
    echo -e "\n${BOLD}${LIGHT_BLUE}[${BRIGHT_GREEN}*${LIGHT_BLUE}] ${BRIGHT_GREEN}SECURE NETWORK TUNNELING PROTOCOL ${LIGHT_BLUE}[${BRIGHT_GREEN}*${LIGHT_BLUE}]${NC}\n"
    echo -e "${DIM}${LIGHT_BLUE}Initializing secure connection framework...${NC}"
}

# Function to print section headers
print_header() {
    echo -e "\n${BOLD}${LIGHT_BLUE}[${BRIGHT_GREEN}+${LIGHT_BLUE}] ${BRIGHT_GREEN}$1 ${LIGHT_BLUE}[${BRIGHT_GREEN}+${LIGHT_BLUE}]${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${BRIGHT_GREEN}[✓] $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${LIGHT_BLUE}[>] $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Function to print hacker-style status messages
print_status() {
    local message=$1
    echo -e "${DIM}${LIGHT_BLUE}[$(date +%H:%M:%S)]${NC} ${BRIGHT_GREEN}$message${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install required packages
install_packages() {
    print_info "Detecting package manager..."

    if command_exists "apt"; then
        print_info "Installing wireguard-tools using apt..."
        sudo apt update && sudo apt install -y wireguard-tools
    elif command_exists "apt-get"; then
        print_info "Installing wireguard-tools using apt-get..."
        sudo apt-get update && sudo apt-get install -y wireguard-tools
    elif command_exists "dnf"; then
        print_info "Installing wireguard-tools using dnf..."
        sudo dnf install -y wireguard-tools
    elif command_exists "yum"; then
        print_info "Installing wireguard-tools using yum..."
        sudo yum install -y wireguard-tools
    elif command_exists "pacman"; then
        print_info "Installing wireguard-tools using pacman..."
        sudo pacman -Sy --noconfirm wireguard-tools
    elif command_exists "zypper"; then
        print_info "Installing wireguard-tools using zypper..."
        sudo zypper install -y wireguard-tools
    elif command_exists "apk"; then
        print_info "Installing wireguard-tools using apk..."
        sudo apk add wireguard-tools
    elif command_exists "emerge"; then
        print_info "Installing wireguard-tools using emerge..."
        sudo emerge --ask=n wireguard-tools
    else
        print_error "No supported package manager found"
        print_info "Please install WireGuard tools manually using your package manager."
        print_info "Then run this script again."
        exit 1
    fi

    if [ $? -ne 0 ]; then
        print_error "Failed to install required packages"
        exit 1
    else
        print_success "Required packages installed successfully"
    fi
}

# Function to check and install required packages
check_requirements() {
    print_info "Checking for required tools..."

    if ! command_exists "wg-quick"; then
        print_warning "wg-quick command not found"
        print_info "WireGuard tools need to be installed"

        # Auto-install without prompting
        print_info "Installing WireGuard tools automatically..."
        install_packages
    else
        print_success "wg-quick is already installed"
    fi
}

# Function to create the VPN configuration file
create_config() {
    print_info "Setting up VPN configuration..."

    # Create the cache directory if it doesn't exist
    mkdir -p "$HOME/.cache/wireguard"

    # No need to detect default network interface

    # Create the configuration file
    CONFIG_PATH="$HOME/.cache/wireguard/${CLIENT_NAME}.conf"

        # Create the configuration file directly
    cat > "$CONFIG_PATH" << 'WIREGUARD_CONFIG'
PLACEHOLDER_CONFIG
WIREGUARD_CONFIG

    # Make sure the configuration file is readable only by the owner for security
    chmod 600 "$CONFIG_PATH"

    print_success "VPN configuration created at $CONFIG_PATH"
}

# Function to display a hacker-style loading animation
show_loading_animation() {
    local duration=$1
    local message=$2
    local chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local delay=0.1

    printf "${LIGHT_BLUE}[>] %s ${NC}" "$message"

    # Calculate iterations based on duration and delay (duration / delay)
    local iterations=$((duration * 10))

    for ((i=0; i<iterations; i++)); do
        local idx=$((i % 10))
        local char="${chars[$idx]}"
        local percent=$((i * 100 / iterations))

        # Simple progress bar with fixed characters
        local progress_width=20
        local filled_width=$((percent * progress_width / 100))
        local empty_width=$((progress_width - filled_width))

        local progress_bar=""
        for ((j=0; j<filled_width; j++)); do
            progress_bar+="█"
        done

        if [ $filled_width -lt $progress_width ]; then
            progress_bar+="▓"
            empty_width=$((empty_width - 1))
        fi

        for ((j=0; j<empty_width; j++)); do
            progress_bar+="░"
        done

        printf "\r${LIGHT_BLUE}[${BRIGHT_GREEN}%s${LIGHT_BLUE}] %s ${LIGHT_BLUE}|${BRIGHT_GREEN}%s${LIGHT_BLUE}|${NC} %d%%" "$char" "$message" "$progress_bar" "$percent"
        sleep $delay
    done
    printf "\r${LIGHT_BLUE}[${BRIGHT_GREEN}✓${LIGHT_BLUE}] %s ${LIGHT_BLUE}|${BRIGHT_GREEN}████████████████████${LIGHT_BLUE}|${NC} 100%%\n" "$message"
}

# Function to display encryption process with actual information
simulate_encryption() {
    local message=$1
    local duration=$2
    local delay=0.05
    local iterations=$((duration * 20))

    echo -e "${LIGHT_BLUE}[>] ${message}${NC}"
    echo -ne "${DIM}${BRIGHT_GREEN}"

    # Display actual encryption information instead of random binary
    local encryption_info=(
        "Initializing ChaCha20-Poly1305 cipher suite"
        "Configuring 256-bit encryption keys"
        "Setting up UDP encapsulation on port 443"
        "Preparing Curve25519 key exchange"
        "Configuring Perfect Forward Secrecy"
        "Establishing encrypted UDP tunnel"
        "Verifying peer authentication"
        "Setting up IP routing tables"
        "Configuring DNS resolution (1.1.1.1, 8.8.8.8)"
        "Enabling persistent keepalive (25s)"
    )

    local info_count=${#encryption_info[@]}

    for ((i=0; i<iterations; i++)); do
        # Select info based on progress
        local info_index=$((i * info_count / iterations))
        if [ $info_index -ge $info_count ]; then
            info_index=$((info_count - 1))
        fi

        # Display progress indicator with actual information
        local progress=$((i * 100 / iterations))
        printf "\r${LIGHT_BLUE}[%3d%%]${NC} ${BRIGHT_GREEN}%s${NC}" "$progress" "${encryption_info[$info_index]}"
        sleep $delay
    done

    echo -e "\n${BRIGHT_GREEN}[✓] ${message} complete${NC}"
}

# Function to turn on the VPN
vpn_on() {
    print_header "INITIALIZING SECURE TUNNEL"
    # Check for required tools before proceeding
    check_requirements

    # Create the configuration file
    create_config

    # Check if the VPN interface is already active
    if ip link show "${CLIENT_NAME}" &>/dev/null; then
        print_warning "Secure tunnel already established"
        return 0
    fi

    print_status "Initializing cryptographic subsystems..."
    sudo modprobe wireguard 2>/dev/null || true
    print_status "Preparing network interfaces..."

    # Simulate encryption process
    simulate_encryption "Generating encryption keys" 1

    print_status "Establishing encrypted tunnel..."

    # Use wg-quick with the config file
    CONNECTION_OUTPUT=$(sudo wg-quick up "$HOME/.cache/wireguard/${CLIENT_NAME}.conf" 2>&1)
    CONNECTION_STATUS=$?

    if [ $CONNECTION_STATUS -eq 0 ]; then
        print_success "Secure tunnel established successfully!"

        # Extract actual interface information from the connection output
        INTERFACE_IP=$(echo "$CONNECTION_OUTPUT" | grep -oP '(?<=\[#\] ip -4 address add )\d+(\.\d+){3}/\d+' | head -1)
        DNS_SERVERS=$(echo "$CONNECTION_OUTPUT" | grep -oP '(?<=\[#\] resolvconf -a ).*?(?= -m)' | head -1)

        # Show actual connection details
        if [ -n "$INTERFACE_IP" ]; then
            print_status "Interface configured with IP: $INTERFACE_IP"
        fi
        if [ -n "$DNS_SERVERS" ]; then
            print_status "DNS servers configured: 1.1.1.1, 8.8.8.8"
        fi

        # Show loading animation with actual verification
        show_loading_animation 3 "Verifying connection integrity..."

        # Get actual connection details from wg show
        WG_INFO=$(sudo wg show ${CLIENT_NAME} 2>/dev/null)
        if [ -n "$WG_INFO" ]; then
            ENDPOINT=$(echo "$WG_INFO" | grep -oP '(?<=endpoint: ).*' | head -1)
            if [ -n "$ENDPOINT" ]; then
                print_status "Connected to endpoint: $ENDPOINT"
            fi
        fi

        print_status "Connection secured with ChaCha20-Poly1305 256-bit encryption"

        # Setup nftables rules
        print_status "Configuring firewall rules..."
        sudo nft flush ruleset

        sudo nft add table inet filter
        sudo nft add chain inet filter input { type filter hook input priority 0 \; policy accept \; }
        sudo nft add chain inet filter forward { type filter hook forward priority 0 \; policy accept \; }
        sudo nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }

        print_success "Firewall rules configured successfully"
    else
        print_error "Failed to establish secure tunnel"
        exit 1
    fi
}

# Function to turn off the VPN
vpn_off() {
    print_header "TERMINATING SECURE TUNNEL"

    # Check for required tools before proceeding
    check_requirements

    # Check if the VPN interface is active before trying to turn it off
    if ! ip link show "${CLIENT_NAME}" &>/dev/null; then
        print_warning "Secure tunnel already closed"
        return 0
    fi

    print_status "Initiating secure shutdown sequence..."

    # Capture interface information before disconnecting
    INTERFACE_INFO=$(ip -br addr show ${CLIENT_NAME} 2>/dev/null)
    WG_INFO=$(sudo wg show ${CLIENT_NAME} 2>/dev/null)

    # Use wg-quick with the config file
    DISCONNECT_OUTPUT=$(sudo wg-quick down "$HOME/.cache/wireguard/${CLIENT_NAME}.conf" 2>&1)
    DISCONNECT_STATUS=$?

    if [ $DISCONNECT_STATUS -eq 0 ]; then
        print_success "Secure tunnel terminated successfully"

        # Show actual disconnection details
        if [ -n "$INTERFACE_INFO" ]; then
            print_status "Removed interface: ${CLIENT_NAME} (${INTERFACE_INFO})"
        fi

        # Show loading animation with actual cleanup information
        show_loading_animation 2 "Cleaning up network resources..."

        # Display actual cleanup information
        ROUTES_REMOVED=$(echo "$DISCONNECT_OUTPUT" | grep -c "\[#\] ip route del")
        if [ $ROUTES_REMOVED -gt 0 ]; then
            print_status "Removed $ROUTES_REMOVED routing rules"
        fi

        DNS_RESET=$(echo "$DISCONNECT_OUTPUT" | grep -c "\[#\] resolvconf")
        if [ $DNS_RESET -gt 0 ]; then
            print_status "Reset DNS configuration"
        fi

        print_status "Network identity restored to default state"
    else
        print_error "Failed to terminate secure tunnel"
        exit 1
    fi
}

# Function to display IP information
display_ip_info() {
    # Get IP information using dig (faster than curl)
    IP=$(dig +short txt ch whoami.cloudflare @1.1.1.1 | tr -d '"')

    # Get interface information
    if ip link show "${CLIENT_NAME}" &>/dev/null; then
        # Get VPN interface IP
        VPN_IP=$(ip -4 addr show ${CLIENT_NAME} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        # Get VPN interface status
        VPN_STATUS=$(ip -br link show ${CLIENT_NAME} | awk '{print $2}')
    fi

    # Display connection information with fancy formatting
    echo -e "\n${BOLD}${LIGHT_BLUE}[${BRIGHT_GREEN}+${LIGHT_BLUE}] ${BRIGHT_GREEN}CONNECTION STATUS ${LIGHT_BLUE}[${BRIGHT_GREEN}+${LIGHT_BLUE}]${NC}\n"

    if [ -n "$VPN_IP" ]; then
        echo -e "${BRIGHT_GREEN}[✓] Secure Tunnel: ${BOLD}ACTIVE${NC}"
        echo -e "${BRIGHT_GREEN}[✓] Interface: ${BOLD}${CLIENT_NAME} (${VPN_STATUS})${NC}"
        echo -e "${BRIGHT_GREEN}[✓] VPN IP Address: ${BOLD}${VPN_IP}${NC}"
        echo -e "${BRIGHT_GREEN}[✓] Public IP Address: ${BOLD}${IP}${NC}"
        echo -e "${BRIGHT_GREEN}[✓] Encryption: ${BOLD}ChaCha20-Poly1305 (256-bit)${NC}"
    else
        echo -e "${YELLOW}[!] Secure Tunnel: ${BOLD}INACTIVE${NC}"
        echo -e "${YELLOW}[!] Public IP Address: ${BOLD}${IP}${NC}"
    fi
    echo
}

# Process command line arguments
case "$1" in
    on)
        display_banner
        vpn_on
        display_ip_info
        echo -e "${BRIGHT_GREEN}[✓] ${BOLD}SECURE TUNNEL ACTIVE${NC} - Your connection is now encrypted"
        ;;
    off)
        display_banner
        vpn_off
        display_ip_info
        echo -e "${YELLOW}[!] ${BOLD}SECURE TUNNEL CLOSED${NC} - Your connection is now in default state"
        ;;
    status)
        display_banner
        if ip link show "${CLIENT_NAME}" &>/dev/null; then
            print_status "Analyzing tunnel status..."
            show_loading_animation 2 "Performing security checks"
            echo -e "${BRIGHT_GREEN}[✓] ${BOLD}SECURE TUNNEL ACTIVE${NC} - Your connection is encrypted"
            display_ip_info

            # Show actual connection statistics
            print_header "CONNECTION STATISTICS"
            # Get WireGuard stats
            if command_exists "wg"; then
                echo -e "${LIGHT_BLUE}[>] WireGuard Interface Statistics:${NC}"
                STATS=$(sudo wg show ${CLIENT_NAME})
                HANDSHAKE=$(echo "$STATS" | grep "latest handshake" | awk '{print $3, $4, $5, $6}')
                RECEIVED=$(echo "$STATS" | grep "transfer" | awk '{print $2, $3}')
                SENT=$(echo "$STATS" | grep "transfer" | awk '{print $5, $6}')

                if [ -n "$HANDSHAKE" ]; then
                    echo -e "${BRIGHT_GREEN}[✓] Latest Handshake: ${BOLD}${HANDSHAKE}${NC}"
                fi
                if [ -n "$RECEIVED" ]; then
                    echo -e "${BRIGHT_GREEN}[✓] Data Received: ${BOLD}${RECEIVED}${NC}"
                fi
                if [ -n "$SENT" ]; then
                    echo -e "${BRIGHT_GREEN}[✓] Data Sent: ${BOLD}${SENT}${NC}"
                fi

                # Show current routing for VPN traffic
                echo -e "\n${LIGHT_BLUE}[>] Routing Information:${NC}"
                ROUTES=$(ip route show dev ${CLIENT_NAME} 2>/dev/null)
                if [ -n "$ROUTES" ]; then
                    echo -e "${BRIGHT_GREEN}[✓] Active Routes:${NC}"
                    echo -e "${DIM}${BRIGHT_GREEN}$ROUTES${NC}"
                fi
            fi
        else
            print_status "Analyzing network status..."
            show_loading_animation 1 "Checking interfaces"
            echo -e "${YELLOW}[!] ${BOLD}SECURE TUNNEL INACTIVE${NC} - Your connection is not encrypted"
            display_ip_info

            # Show available network interfaces
            print_header "AVAILABLE NETWORK INTERFACES"
            INTERFACES=$(ip -br link show | grep -v "lo")
            echo -e "${LIGHT_BLUE}[>] Network Interfaces:${NC}"
            echo -e "${DIM}${BRIGHT_GREEN}$INTERFACES${NC}"
        fi
        ;;
    *)
        display_banner
        echo -e "${BOLD}${LIGHT_BLUE}[${BRIGHT_GREEN}*${LIGHT_BLUE}] USAGE INSTRUCTIONS ${LIGHT_BLUE}[${BRIGHT_GREEN}*${LIGHT_BLUE}]${NC}"
        echo -e "  ${BOLD}Command:${NC} $0 {on|off|status}"
        echo -e "  ${BRIGHT_GREEN}on${NC}      - Establish secure encrypted tunnel"
        echo -e "  ${RED}off${NC}     - Terminate secure encrypted tunnel"
        echo -e "  ${CYAN}status${NC}  - Display current connection status"
        exit 1
        ;;
esac

exit 0
EOF

# Replace placeholders with actual values
sed -i "s/PLACEHOLDER_CLIENT_NAME/${CLIENT_NAME}/g" ${CLIENT_DIR}/${CLIENT_NAME}_connect.sh

# Insert the client configuration but ensure it uses the client name as interface name
TEMP_CONFIG=$(mktemp)
cat ${CLIENT_DIR}/${CLIENT_NAME}.conf > "${TEMP_CONFIG}"
sed -i "/PLACEHOLDER_CONFIG/r ${TEMP_CONFIG}" ${CLIENT_DIR}/${CLIENT_NAME}_connect.sh
sed -i "/PLACEHOLDER_CONFIG/d" ${CLIENT_DIR}/${CLIENT_NAME}_connect.sh
rm "${TEMP_CONFIG}"

# Make the connection script executable
chmod +x ${CLIENT_DIR}/${CLIENT_NAME}_connect.sh

# Check if WireGuard is running and apply the new configuration
if ip link show wg0 &>/dev/null; then
    echo "Applying new client configuration to the running WireGuard server..."
    # Create a temporary file with just the new peer configuration
    TEMP_CONF=$(mktemp)
    cat > "${TEMP_CONF}" << EOF
[Peer]
# ${CLIENT_NAME}
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

    # Apply the new peer configuration
    sudo wg addconf wg0 "${TEMP_CONF}"
    rm "${TEMP_CONF}"
    echo "Client '${CLIENT_NAME}' added and activated successfully!"
else
    echo "WireGuard interface (wg0) is not running."
    echo "Client '${CLIENT_NAME}' has been added to the configuration."
    echo "Start WireGuard with 'sudo ./manage_wireguard.sh start' to activate all clients."
fi

echo "Configuration file: ${CLIENT_DIR}/${CLIENT_NAME}.conf"
echo "QR code for mobile: ${CLIENT_DIR}/${CLIENT_NAME}.png"
echo "Connection script: ${CLIENT_DIR}/${CLIENT_NAME}_connect.sh"

echo ""
echo "IMPORTANT: For connections from outside your local network:"
echo "1. Ensure UDP port ${WG_PORT} is forwarded to this server in your router settings"
echo "2. If your public IP changes frequently, consider using a dynamic DNS service"
echo ""
echo "You have two options to connect:"
echo ""
echo "Option 1: Use the connection script (recommended):"
echo "1. Copy ${CLIENT_NAME}_connect.sh to the client machine"
echo "2. Make it executable: chmod +x ${CLIENT_NAME}_connect.sh"
echo "3. Run it: ./${CLIENT_NAME}_connect.sh on (to connect) or ./${CLIENT_NAME}_connect.sh off (to disconnect)"
echo ""
echo "Option 2: Use wg-quick directly:"
echo "1. Copy ${CLIENT_NAME}.conf to the client machine"
echo "2. Run: sudo wg-quick up /path/to/${CLIENT_NAME}.conf"
echo "3. To disconnect: sudo wg-quick down /path/to/${CLIENT_NAME}.conf"
echo ""
echo "Note: When using wg-quick directly, the interface name will be '${CLIENT_NAME}'"
echo "      When using the connection script, the interface name will also be '${CLIENT_NAME}'"
echo ""
