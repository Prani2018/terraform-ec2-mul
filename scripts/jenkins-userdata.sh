#!/bin/bash

# Redirect all output to a log file
exec > >(tee ${log_file}) 2>&1

#Set PATH
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
echo 'export PATH' >> /etc/environment

hostnamectl set-hostname jenkins-server;/bin/bash

echo "=== Starting Jenkins installation at $(date) ==="

# Update system
apt-get update -y
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to update system packages"
    exit 1
fi

# Install Java 17 and dependencies
apt-get install -y openjdk-17-jdk wget curl gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Java and dependencies"
    exit 1
fi

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment
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
# ... your other Jenkins installation commands ...


# Modify the Jenkins startup configuration to disable the setup wizard
# This is a more reliable approach than just modifying files
sed -i 's/JAVA_ARGS="/JAVA_ARGS="-Djenkins.install.runSetupWizard=false /' /etc/default/jenkins

# Ensure Jenkins configuration directory is ready and owned correctly
mkdir -p /var/lib/jenkins/init.groovy.d
chown -R jenkins:jenkins /var/lib/jenkins

# Disable the setup wizard
echo 2.0 > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion


chown jenkins:jenkins /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

# Create a temporary Groovy script to set the install state to completed
# This is a different approach than modifying config.xml, and sometimes more reliable
####cat <<EOF > /var/lib/jenkins/init.groovy.d/set_install_state.groovy
####import jenkins.model.*
####import jenkins.install.*
####def instance = Jenkins.getInstance()
####instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
####EOF
####chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/set_install_state.groovy
####
####systemctl restart jenkins
####
##### Temporarily disable security to run the Groovy script
####sed -i 's/<useSecurity>true/<useSecurity>false/' /var/lib/jenkins/config.xml
####chown jenkins:jenkins /var/lib/jenkins/config.xml
####systemctl restart jenkins
####
##### Wait for Jenkins to be ready
####until $(curl --output /dev/null --silent --head --fail http://localhost:8080); do
####    printf '.'
####    sleep 5
####done
####
# Create the initial admin user with a groovy script
JENKINS_USER="ksarikon"
JENKINS_PASS="!9apr2015"
JENKINS_EMAIL="jbossadmin@gmail.com"




cat <<EOF > /var/lib/jenkins/init.groovy.d/create_user.groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
instance.setSecurityRealm(hudsonRealm)
instance.save()

def user = hudsonRealm.createAccount('$JENKINS_USER', '$JENKINS_PASS')
user.setFullName('$JENKINS_USER')
user.addProperty(new hudson.model.User.Property.EmailAddressProperty('$JENKINS_EMAIL'))
user.save()

instance.setAuthorizationStrategy(new AuthorizationStrategy.Unsecured())
instance.save()
EOF

# Ensure the Groovy script is owned by the Jenkins user
chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/create_user.groovy
chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/create_user_and_enable_security.groovy

# Re-enable security and restart Jenkins
###sed -i 's/<useSecurity>false/<useSecurity>true/' /var/lib/jenkins/config.xml

# Restart Jenkins to apply changes
systemctl restart jenkins

echo "Waiting for Jenkins to apply configurations..."
# Wait for Jenkins to be ready
until $(curl --output /dev/null --silent --head --fail http://localhost:8080); do
    printf '.'
    sleep 5
done


echo "Jenkins configuration applied successfully"
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



