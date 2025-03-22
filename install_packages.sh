#!/bin/bash

#  exit on any error
set -e
exec 1> >(logger -s -t $(basename $0)) 2>&1


# Update package list and upgrade all packages
echo "Updating package list and upgrading packages..." >> ~/install.log
sudo apt update && sudo apt upgrade -y

# Perform distribution upgrade
echo "$(date): Performing distribution upgrade..." >> ~/install.log
sudo apt dist-upgrade -y

# Clean up unused packages
echo "Cleaning up..."
sudo apt autoremove -y
sudo apt autoclean

sudo apt install -y jq gh git curl unzip wget pwgen dotnet-sdk-8.0
echo "$(date): System update completed!" >> ~/install.log


RUNNER_USER="githubuser"
RUNNER_PASSWORD=$(pwgen -s 20 1)
# echo "Create GH user"
sudo useradd -m -s /bin/bash $RUNNER_USER
echo "$RUNNER_USER:$RUNNER_PASSWORD" | sudo chpasswd
# passwd -d $RUNNER_USER

# # add user to sudo group
sudo usermod -aG sudo $RUNNER_USER

# #  login as githubuser
su - $RUNNER_USER


# Install required packages
echo "Installing azcli" >> ~/install.log
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "$(date): Required packages installed!" >> ~/install.log


export RUNNER_VERSION=2.321.0
export GITHUB_OWNER="miekki"
export GITHUB_REPO="use-self-hosted-runner"
export keyvault_name="gh-runners-kv"
export runner_group_name="default"

echo "$(date): RUNNER_VERSION $RUNNER_VERSION" >> ~/install.log
echo "$(date): GITHUB_OWNER $GITHUB_OWNER" >> ~/install.log
echo "$(date): GITHUB_REPO $GITHUB_REPO" >> ~/install.log
echo "$(date): keyvault_name $keyvault_name" >> ~/install.log

az login --identity
GITHUB_TOKEN=$(az keyvault secret show --name "GITHUBPAT" --vault-name "${keyvault_name}" --query "value" -o tsv)

if [ -z "$GITHUB_TOKEN" ]; then
    echo "$(date): GITHUB_TOKEN is empty" >> ~/install.log
    exit 1
fi
echo "$(date): GETTING TOKEN dowloaded" >> ~/install.log

# cd /opt
mkdir -p ~/actions-runner 
cd ~/actions-runner


curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# sudo chown -R $USER:$USER /opt/actions-runner
# sudo chmod -R 755 /opt/actions-runner

echo "$(date): Downloaded agent" >> ~/install.log

TOKEN=$(curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runners/registration-token | jq -r '.token')

if [ -z "$TOKEN" ]; then
    echo "TOKEN is empty" >> ~/install.log
    exit 1
fi

echo "$(date): Get token from GitHub" >> ~/install.log

./config.sh --url "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}" --token ${TOKEN} --unattended --replace --name "$HOSTNAME" --runnergroup "${runner_group_name}" --work "_work"
sudo ./svc.sh install $RUNNER_USER
sudo ./svc.sh start

echo "$(date): Service installed and started" >> ~/install.log


