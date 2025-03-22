#!/bin/bash

# Update package list and upgrade all packages
echo "Updating package list and upgrading packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Perform distribution upgrade
echo "Performing distribution upgrade..."
sudo apt-get dist-upgrade -y

# Clean up unused packages
echo "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get autoclean

echo "System update completed!"