# 🔒 GhostWire VPN
![20250418-195635](https://github.com/user-attachments/assets/e70aaf7e-2502-437f-9a48-aba8509b231d)

<div align="center">

  ![GhostWire VPN](https://img.shields.io/badge/GhostWire-VPN-brightgreen?style=for-the-badge)
  ![WireGuard](https://img.shields.io/badge/WireGuard-88171A?style=for-the-badge&logo=wireguard&logoColor=white)
  ![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
  ![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
  ![Security](https://img.shields.io/badge/Security-First-blue?style=for-the-badge)

  *A lightweight, high-performance WireGuard VPN solution designed to bypass network restrictions*
</div>

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [System Requirements](#-system-requirements)
- [Installation](#-installation)
- [Server Configuration](#-server-configuration)
- [Client Management](#-client-management)
  - [Adding Clients](#adding-clients)
  - [Listing Clients](#listing-clients)
  - [Removing Clients](#removing-clients)
- [Client Connection](#-client-connection)
- [Security Considerations](#-security-considerations)
- [Troubleshooting](#-troubleshooting)
- [Advanced Configuration](#-advanced-configuration)
- [Technical Details](#-technical-details)

## 🔍 Overview

GhostWire VPN is a custom WireGuard-based VPN solution designed to provide secure, encrypted tunneling through restrictive network environments. It operates on port 443 to bypass common firewall restrictions by mimicking HTTPS traffic. This project includes a complete suite of scripts for server setup, client management, and connection handling.

> **Note:** This project is intended for educational purposes and legitimate use cases such as accessing resources on your college network securely. Always comply with your institution's acceptable use policies.

## ✨ Features

- **Port 443 Operation**: Uses the standard HTTPS port to avoid common firewall restrictions
- **Modern Cryptography**: Leverages WireGuard's state-of-the-art cryptographic protocols (ChaCha20, Poly1305, Curve25519)
- **Streamlined Client Management**: Simple scripts for adding, listing, and removing clients
- **Automated Client Setup**: Generates ready-to-use connection scripts for clients
- **QR Code Generation**: Creates scannable QR codes for mobile device configuration
- **Connection Monitoring**: Real-time status information and connection statistics
- **Backup Management**: Automatic configuration backups with rotation
- **Cross-Platform Support**: Works on Linux, macOS, Windows, iOS, and Android

## 💻 System Requirements

### Server Requirements
- Linux-based operating system
- Root/sudo access
- WireGuard kernel module or wireguard-go
- iptables for network routing
- qrencode (for QR code generation)

### Client Requirements
- Any platform with WireGuard support:
  - Linux
  - macOS
  - Windows
  - iOS
  - Android

## 🚀 Installation

### Server Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/ghostwire-vpn.git
   cd ghostwire-vpn
   ```

2. Make all scripts executable:
   ```bash
   chmod +x *.sh
   ```

3. Enable IP forwarding (required for routing VPN traffic):
   ```bash
   sudo ./enable_ip_forwarding.sh
   ```

4. Check if port 443 is available:
   ```bash
   sudo ./check_port.sh
   ```

5. Start the WireGuard server:
   ```bash
   sudo ./manage_wireguard.sh start
   ```

## ⚙️ Server Configuration

The server configuration is stored in `config/wg0.conf`. This file contains:

- Server's private key
- Listening port (443)
- Server's VPN subnet address (10.10.0.1/24)
- PostUp/PostDown scripts for routing and firewall rules
- Peer (client) configurations

The default configuration uses:
- Network: 10.10.0.0/24
- Server IP: 10.10.0.1
- Client IPs: Starting from 10.10.0.2 and incrementing

### Key Server Files

- `config/wg0.conf`: Main WireGuard configuration
- `config/server_public.key`: Server's public key
- `config/server_private.key`: Server's private key (keep secure!)
- `config/backups/`: Directory containing configuration backups

## 🧑‍💻 Client Management

### Adding Clients

To add a new client:

```bash
sudo ./add_client.sh client_name
```

This script:
1. Generates client private/public key pair
2. Assigns a unique IP address in the VPN subnet
3. Creates client configuration file
4. Adds the client to the server configuration
5. Generates a QR code for mobile devices
6. Creates a user-friendly connection script
7. Applies changes to the running WireGuard server (if active)

All client files are stored in `clients/client_name/`:
- `private.key`: Client's private key
- `public.key`: Client's public key
- `client_name.conf`: WireGuard configuration file
- `client_name.png`: QR code for mobile configuration
- `client_name_connect.sh`: Connection script for easy setup

### Listing Clients

To list all configured clients and their status:

```bash
sudo ./list_clients.sh
```

This displays:
- Client name
- Public key
- IP address
- Connection status (if WireGuard is running)
- Data transfer statistics (for connected clients)
- Paths to configuration files and QR codes

### Removing Clients

To remove a client:

```bash
sudo ./delete_client.sh client_name
```

This script:
1. Removes the client from the server configuration
2. Creates a backup of the previous configuration
3. Applies changes to the running WireGuard server (if active)
4. Deletes all client files
5. Lists remaining clients

## 🔌 Client Connection

Clients can connect using one of two methods:

### Method 1: Using the Connection Script (Recommended)

1. Copy the `client_name_connect.sh` script to the client machine
2. Make it executable:
   ```bash
   chmod +x client_name_connect.sh
   ```
3. Run the script:
   ```bash
   ./client_name_connect.sh on    # To connect
   ./client_name_connect.sh off   # To disconnect
   ./client_name_connect.sh status # To check connection status
   ```

The connection script provides:
- Automatic installation of WireGuard tools if needed
- Visual connection status with encryption details
- Real-time connection statistics
- Proper cleanup on disconnection

### Method 2: Using WireGuard Tools Directly

1. Copy the `client_name.conf` file to the client machine
2. Connect using WireGuard tools:
   - **Linux/macOS**:
     ```bash
     sudo wg-quick up /path/to/client_name.conf
     ```
   - **Windows**: Import the configuration in the WireGuard application
   - **Mobile**: Scan the QR code using the WireGuard app

## 🔐 Security Considerations

- **Private Keys**: Keep all private keys secure. The server's private key is particularly sensitive.
- **Port Forwarding**: For external access, ensure UDP port 443 is forwarded to your server.
- **IP Forwarding**: Required for routing traffic; enabled by `enable_ip_forwarding.sh`.
- **Firewall Rules**: The PostUp/PostDown scripts in `wg0.conf` configure necessary iptables rules.
- **DNS Leakage**: Client configurations use secure DNS servers (1.1.1.1, 8.8.8.8) to prevent DNS leakage.

## 🔧 Troubleshooting

### Common Issues

1. **Connection Failures**:
   - Verify port 443 is open and forwarded to your server
   - Check server logs: `sudo journalctl -u wg-quick@wg0`
   - Ensure IP forwarding is enabled: `cat /proc/sys/net/ipv4/ip_forward`

2. **Client Can't Connect**:
   - Verify the server's public IP is correct in client configuration
   - Check if the client's public key is properly added to the server
   - Ensure no firewall is blocking UDP port 443

3. **Internet Access Issues After Connection**:
   - Verify PostUp/PostDown scripts in server configuration
   - Check routing tables on server: `ip route show`
   - Ensure masquerading is working: `sudo iptables -t nat -L POSTROUTING`

### Diagnostic Commands

- Check WireGuard status: `sudo ./manage_wireguard.sh status`
- View WireGuard interfaces: `sudo wg show`
- Check routing: `ip route show`
- Verify port availability: `sudo ./check_port.sh`

## 🛠️ Advanced Configuration

### Changing the VPN Subnet

To use a different subnet than 10.10.0.0/24:
1. Edit `config/wg0.conf` and change the `Address` line
2. Update the `add_client.sh` script to assign IPs in the new subnet
3. Restart WireGuard: `sudo ./manage_wireguard.sh restart`

### Using a Different Port

To change from port 443:
1. Edit `config/wg0.conf` and change the `ListenPort` value
2. Update `add_client.sh` to use the new port (WG_PORT variable)
3. Update `check_port.sh` to check the new port
4. Restart WireGuard: `sudo ./manage_wireguard.sh restart`

### Custom DNS Servers

To use different DNS servers for clients:
1. Edit the `add_client.sh` script and modify the DNS line in the client configuration template
2. New clients will use the specified DNS servers

## 📊 Technical Details

### Cryptographic Primitives

GhostWire VPN uses WireGuard's cryptographic suite:
- **Encryption**: ChaCha20 (256-bit keys)
- **Authentication**: Poly1305 MAC
- **Key Exchange**: Curve25519
- **Perfect Forward Secrecy**: Enabled by default

### Network Architecture

- **Tunnel Type**: Layer 3 VPN (IP packets)
- **Protocol**: UDP on port 443
- **Addressing**: Private subnet (10.10.0.0/24)
- **Routing**: All traffic routed through VPN (0.0.0.0/0)
- **Keepalive**: 25-second intervals to maintain NAT mappings

### Performance Considerations

- WireGuard is designed for high performance with low overhead
- Minimal CPU usage compared to OpenVPN or IPsec
- Low latency due to efficient handshake mechanism
- Roaming support for mobile clients changing networks

---

<div align="center">
  <p>
    <strong>GhostWire VPN</strong> - Secure. Fast. Undetectable.
  </p>
  <p>
    Created by <a href="https://github.com/FelipeFMA">FelipeFMA</a>
  </p>
</div>
