#!/bin/bash

# Redirect all output to a log file
exec > >(tee ${log_file}) 2>&1

echo "=== Starting Jenkins installation at $(date) ==="

# Update system
apt-get update -y
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to update system packages"
    exit 1
fi

# Install Java 11 and dependencies
apt-get install -y openjdk-11-jdk wget curl gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Java and dependencies"
    exit 1
fi

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /etc/environment
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/environment

echo "Java installed successfully: $(java -version)"

# Add Jenkins repository key and repository
echo "Adding Jenkins repository..."
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package index
apt-get update -y

# Install Jenkins
apt-get install -y jenkins
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Jenkins"
    exit 1
fi

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

echo "Waiting for Jenkins to start..."
sleep 30

# Check if Jenkins is running
if systemctl is-active --quiet jenkins; then
    echo "Jenkins service started successfully"
else
    echo "ERROR: Jenkins service failed to start"
    systemctl status jenkins
    exit 1
fi

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Add jenkins user to docker group
usermod -aG docker jenkins

# Start and enable Docker
systemctl start docker
systemctl enable docker

echo "Docker installed and configured"

# Install Git
apt-get install -y git
echo "Git installed: $(git --version)"

# Install Maven
echo "Installing Maven..."
cd /opt
wget -q https://archive.apache.org/dist/maven/maven-3/3.9.5/binaries/
