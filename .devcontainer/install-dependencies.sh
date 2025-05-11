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

echo "Installing ngrok - revers proxy need it for gh webhooks"
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list \
  && sudo apt update \
  && sudo apt install ngrok