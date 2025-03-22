#!/bin/bash

#  exit on any error
set -e
exec 1> >(logger -s -t $(basename $0)) 2>&1


# Update package list and upgrade all packages
echo "$(date): Updating package list and upgrading packages..."
sudo apt update && sudo apt upgrade -y

# Perform distribution upgrade
echo "$(date): Performing distribution upgrade..."
sudo apt dist-upgrade -y

# Clean up unused packages
echo "Cleaning up..."
sudo apt autoremove -y
sudo apt autoclean

sudo apt install -y jq gh git curl unzip wget pwgen dotnet-sdk-8.0
echo "$(date): System update completed!" 


RUNNER_USER="githubuser"
RUNNER_PASSWORD=$(pwgen -s 20 1)
RUNNER_DIR="/home/$RUNNER_USER/actions-runner"
# echo "Create GH user"
sudo useradd -m -s /bin/bash $RUNNER_USER
echo "$RUNNER_USER:$RUNNER_PASSWORD" | sudo chpasswd
# passwd -d $RUNNER_USER

# # add user to sudo group
sudo usermod -aG sudo $RUNNER_USER

# #  login as githubuser
# su - $RUNNER_USER

echo "$(date): User set up" 

# Install required packages
echo "Installing azcli" 
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "$(date): Required packages installed!"

LOG_FILE="home/$RUNNER_USER/install.log"
sudo touch "$LOG_FILE"
sudo chown $RUNNER_USER:$RUNNER_USER "$LOG_FILE"

sudo -u $RUNNER_USER bash << EOF
echo "\$(date): Starting runner configuration" >> $LOG_FILE
RUNNER_USER="githubuser"
RUNNER_DIR="/home/$RUNNER_USER/actions-runner"
export RUNNER_VERSION=2.321.0
export GITHUB_OWNER="miekki"
export GITHUB_REPO="use-self-hosted-runner"
export keyvault_name="gh-runners-kv"
export runner_group_name="default"

echo "\$(date): RUNNER_VERSION \$RUNNER_VERSION" >> $LOG_FILE
echo "\$(date): GITHUB_OWNER \$GITHUB_OWNER" >> $LOG_FILE
echo "\$(date): GITHUB_REPO \$GITHUB_REPO" >> $LOG_FILE
echo "\$(date): keyvault_name \$keyvault_name" >> $LOG_FILE

az login --identity
GITHUB_TOKEN=\$(az keyvault secret show --name "GITHUBPAT" --vault-name "${keyvault_name}" --query "value" -o tsv)

if [ -z "\$GITHUB_TOKEN" ]; then
    echo "\$(date): GITHUB_TOKEN is empty" >> $LOG_FILE
    exit 1
fi
echo "\$(date): GETTING TOKEN dowloaded" >> $LOG_FILE

mkdir -p \${RUNNER_DIR} 
cd \${RUNNER_DIR}

curl -o actions-runner-linux-x64-\${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v\${RUNNER_VERSION}/actions-runner-linux-x64-\${RUNNER_VERSION}.tar.gz
tar xzf actions-runner-linux-x64-\${RUNNER_VERSION}.tar.gz

echo "\$(date): Downloaded agent" >> $LOG_FILE

TOKEN=\$(curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer \$GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runners/registration-token | jq -r '.token')

if [ -z "\$TOKEN" ]; then
    echo "TOKEN is empty" >>$LOG_FILE
    exit 1
fi

echo "\$(date): Get token from GitHub" >> $LOG_FILE

./config.sh --url "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}" --token "\${TOKEN}" --unattended --replace --name "\$HOSTNAME" --runnergroup "${runner_group_name}" --work "_work" --labels "azure-vmss"
EOF

echo "$(date): Runner configured" >> $LOG_FILE
cd $RUNNER_DIR

sudo ./svc.sh install $RUNNER_USER

echo "$(date): Service installed" >> $LOG_FILE

sudo ./svc.sh start

echo "$(date): Service installed and started" >> $LOG_FILE


