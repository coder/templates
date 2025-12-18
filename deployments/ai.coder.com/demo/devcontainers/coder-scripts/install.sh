#!/usr/bin/env bash

set -eu

# Need root to run apt
sudo su 'root' -c sh -c '
apt update -y
apt install -y \
    apt-transport-https ca-certificates curl gnupg software-properties-common

# Add GPG Key Rings to Apt
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Add to Apt Repos
add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu focal stable"

# Extra pre-installs
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# Finalize Installations
apt update -y
apt install -y \
    nodejs \
    docker docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Finished!"
'

npm config set prefix=~
npm install -g @devcontainers/cli

# Force create docker group and add user to it.
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $(whoami) 2>/dev/null || true
newgrp docker 2>/dev/null || true

exit 0;