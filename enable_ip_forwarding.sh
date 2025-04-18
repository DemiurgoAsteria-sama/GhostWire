#!/bin/bash

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf

# Make sure the changes persist after reboot
echo "IP forwarding has been enabled and will persist after reboot."
