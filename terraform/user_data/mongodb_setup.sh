#!/bin/bash
set -euxo pipefail

#Detect Amazon Linux version to configure the correct repository
source /etc/os-release

if [[ "$ID" == "amzn" && "$VERSION_ID" == "2" ]]; then
    REPO_DIR="2"
elif [[ "$ID" == "amzn" && "$VERSION_ID" == "2023" ]]; then
    REPO_DIR="2023"
else
    echo "Unsupported operating system"
    exit 1
fi

# Add MongoDB 7.0 repository for Amazon Linux 2
cat > /etc/yum.repos.d/mongodb-org-7.0.repo <<'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/${REPO_DIR}/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF
# Update packages and install MongoDB
yum update -y
yum install -y mongodb-org
# Start MongoDB and enable it on reboot
systemctl enable --now mongod