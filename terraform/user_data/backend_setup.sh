#!/bin/bash
# Strict error handling from your script: fail fast, print commands as they run
set -euxo pipefail

# Install Docker and the Docker Compose plugin on Amazon Linux 2.
yum update -y
amazon-linux-extras install docker -y
systemctl enable --now docker
usermod -aG docker ec2-user

# Create the modern V2 CLI plugins directory structure
mkdir -p /usr/local/lib/docker/cli-plugins

# Download the latest stable version of Docker Compose V2
ARCH="x86_64"
curl -fSL https://github.com/docker/compose/releases/download/v5.6.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose