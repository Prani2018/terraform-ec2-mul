# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
  default     = "kk"
}

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the default subnet
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.aws_region}a"
  default_for_az    = true
}

# Get the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-instances-sg"
  description = "Security group for EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tomcat and Jenkins port
  ingress {
    description = "Tomcat/Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2-Instances-SG"
  }
}

#resource "aws_key_pair" "kk-west" {
#  key_name   = "kk-west"
#  public_key = file("~/.ssh/kk-west.pem")   # must be the PUBLIC key, not the .pem
#}


# EC2 Instance 1 - Tomcat Server
resource "aws_instance" "tomcat_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  #subnet_id             = var.create_vpc ? aws_subnet.public[0].id : data.aws_subnet.default[0].id
  subnet_id              = data.aws_subnet.default.id   # ✅ FIXED: no reference to undeclared aws_subnet.public

  # User data script to install and configure Tomcat
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y openjdk-11-jdk wget curl

              # Set JAVA_HOME
              echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /etc/environment
              echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/environment
              sudo source /etc/environment

              # Create tomcat user
              sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat

              # Download and install Tomcat 10
              cd /tmp
              sudo wget https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.15/bin/apache-tomcat-10.1.15.tar.gz
              sudo tar -xf apache-tomcat-10.1.15.tar.gz -C /opt/tomcat --strip-components=1

              # Set permissions
              sudo chown -R tomcat: /opt/tomcat
              sudo sh -c 'chmod +x /opt/tomcat/bin/*.sh'

              # Create systemd service file
              sudo cat > /etc/systemd/system/tomcat.service << 'EOF'
[Unit]
Description=Tomcat 10 servlet container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"

Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOL

              # Enable and start Tomcat service
              systemctl daemon-reload
              systemctl enable tomcat
              systemctl start tomcat

              # Create a simple test page
              mkdir -p /opt/tomcat/webapps/test
              cat > /opt/tomcat/webapps/test/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Tomcat Server</title>
</head>
<body>
    <h1>Welcome to Tomcat Server!</h1>
    <p>This is the Tomcat EC2 instance.</p>
    <p>Tomcat is running on port 8080.</p>
</body>
</html>
EOL

              chown tomcat:tomcat /opt/tomcat/webapps/test/index.html
              EOF

  tags = {
    Name        = "Tomcat-Server"
    Environment = "Development"
    Project     = "Terraform-Demo"
    Service     = "Tomcat"
  }
}

# EC2 Instance 2 - Maven Server
resource "aws_instance" "maven_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id             = data.aws_subnet.default.id

  # User data script to install and configure Maven
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y openjdk-11-jdk wget curl git apache2

              # Set JAVA_HOME
              echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /etc/environment
              echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/environment

              # Download and install Maven
              cd /opt
              wget https://archive.apache.org/dist/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz
              tar -xzf apache-maven-3.9.5-bin.tar.gz
              mv apache-maven-3.9.5 maven

              # Set Maven environment variables
              echo 'export M2_HOME=/opt/maven' >> /etc/environment
              echo 'export MAVEN_HOME=/opt/maven' >> /etc/environment
              echo 'export PATH=/opt/maven/bin:$PATH' >> /etc/environment

              # Create symbolic links
              ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

              # Start and enable Apache
              systemctl start apache2
              systemctl enable apache2

              # Create info page
              cat > /var/www/html/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Maven Build Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .info { background-color: #f4f4f4; padding: 15px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Welcome to Maven Build Server!</h1>
    <p>This Ubuntu EC2 instance is configured with Maven for building Java projects.</p>
    
    <div class="info">
        <h3>Installed Software:</h3>
        <ul>
            <li>Ubuntu 22.04 LTS</li>
            <li>OpenJDK 11</li>
            <li>Apache Maven 3.9.5</li>
            <li>Git</li>
            <li>Apache Web Server</li>
        </ul>
    </div>

    <div class="info">
        <h3>Environment Variables:</h3>
        <p><strong>JAVA_HOME:</strong> /usr/lib/jvm/java-11-openjdk-amd64</p>
        <p><strong>MAVEN_HOME:</strong> /opt/maven</p>
        <p><strong>M2_HOME:</strong> /opt/maven</p>
    </div>

    <div class="info">
        <h3>Usage:</h3>
        <p>SSH into this instance and run:</p>
        <code>mvn --version</code> to verify Maven installation<br>
        <code>java -version</code> to verify Java installation
    </div>
</body>
</html>
EOL

              # Create a sample Maven project
              mkdir -p /home/ubuntu/projects
              cd /home/ubuntu/projects
              
              # Source environment variables
              source /etc/environment
              
              # Create a simple Maven project structure
              mkdir -p sample-project/src/main/java/com/example
              mkdir -p sample-project/src/test/java/com/example
              
              # Create pom.xml
              cat > sample-project/pom.xml << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>sample-project</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
EOL

              # Create a simple Java class
              cat > sample-project/src/main/java/com/example/HelloWorld.java << 'EOL'
package com.example;

public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello from Maven Build Server!");
    }
    
    public String getMessage() {
        return "Hello from Maven Build Server!";
    }
}
EOL

              # Create a test class
              cat > sample-project/src/test/java/com/example/HelloWorldTest.java << 'EOL'
package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

public class HelloWorldTest {
    @Test
    public void testGetMessage() {
        HelloWorld hw = new HelloWorld();
        assertEquals("Hello from Maven Build Server!", hw.getMessage());
    }
}
EOL

              # Set ownership
              chown -R ubuntu:ubuntu /home/ubuntu/projects
              
              EOF

  tags = {
    Name        = "Maven-Server"
    Environment = "Development"
    Project     = "Terraform-Demo"
    Service     = "Maven"
  }
}

# EC2 Instance 3 - Jenkins Server
resource "aws_instance" "jenkins_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id             = data.aws_subnet.default.id

  # User data script to install and configure Jenkins
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              
              # Install Java 11 (required for Jenkins)
              apt-get install -y openjdk-11-jdk wget curl gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release

              # Set JAVA_HOME
              echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /etc/environment
              echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/environment
              source /etc/environment

              # Add Jenkins repository key
              wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | apt-key add -
              
              # Add Jenkins repository
              echo "deb https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list

              # Update package index
              apt-get update -y

              # Install Jenkins
              apt-get install -y jenkins

              # Start and enable Jenkins
              systemctl start jenkins
              systemctl enable jenkins

              # Install Docker (useful for Jenkins CI/CD)
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io

              # Add jenkins user to docker group
              usermod -aG docker jenkins
              
              # Start and enable Docker
              systemctl start docker
              systemctl enable docker

              # Install Git
              apt-get install -y git

              # Install Maven (for Jenkins builds)
              cd /opt
              wget https://archive.apache.org/dist/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz
              tar -xzf apache-maven-3.9.5-bin.tar.gz
              mv apache-maven-3.9.5 maven
              ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

              # Set Maven environment variables
              echo 'export M2_HOME=/opt/maven' >> /etc/environment
              echo 'export MAVEN_HOME=/opt/maven' >> /etc/environment
              echo 'export PATH=/opt/maven/bin:$PATH' >> /etc/environment

              # Install Node.js (useful for modern web projects)
              curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
              apt-get install -y nodejs

              # Wait for Jenkins to fully start
              sleep 30

              # Get the initial admin password
              JENKINS_PASSWORD=""
              while [ -z "$JENKINS_PASSWORD" ] && [ ! -f /var/lib/jenkins/secrets/initialAdminPassword ]; do
                  echo "Waiting for Jenkins to generate initial password..."
                  sleep 10
              done

              if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
                  JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
                  
                  # Create a file with Jenkins info
                  cat > /home/ubuntu/jenkins-info.txt << EOL
Jenkins Installation Complete!

Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080

Initial Admin Password: $JENKINS_PASSWORD

Next Steps:
1. Open Jenkins in your browser using the URL above
2. Use the initial admin password to unlock Jenkins
3. Install suggested plugins
4. Create your first admin user
5. Start creating your CI/CD pipelines!

Installed Tools:
- Java 11
- Jenkins (Latest LTS)
- Docker
- Git
- Maven 3.9.5
- Node.js 18

Jenkins runs as a service and will start automatically on boot.
EOL
                  
                  chown ubuntu:ubuntu /home/ubuntu/jenkins-info.txt
              fi

              # Install Apache for a simple info page
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2

              # Create info page
              cat > /var/www/html/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Jenkins CI/CD Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f8f9fa; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #326ce5; margin-bottom: 30px; }
        .info { background-color: #e3f2fd; padding: 20px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #2196f3; }
        .warning { background-color: #fff3cd; padding: 20px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #ffc107; }
        .success { background-color: #d4edda; padding: 20px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #28a745; }
        ul li { margin: 8px 0; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Jenkins CI/CD Server</h1>
            <p>Your Jenkins automation server is ready!</p>
        </div>

        <div class="success">
            <h3>✅ Installation Status</h3>
            <p>Jenkins has been successfully installed and is running on this Ubuntu 22.04 LTS instance.</p>
        </div>

        <div class="warning">
            <h3>🔑 First Time Setup Required</h3>
            <p>Jenkins requires initial setup with the admin password.</p>
            <p>SSH into the server and run: <code>sudo cat /var/lib/jenkins/secrets/initialAdminPassword</code></p>
            <p>Or check the file: <code>/home/ubuntu/jenkins-info.txt</code></p>
        </div>

        <div class="info">
            <h3>🛠️ Installed Software</h3>
            <ul>
                <li><strong>Operating System:</strong> Ubuntu 22.04 LTS</li>
                <li><strong>Java:</strong> OpenJDK 11</li>
                <li><strong>Jenkins:</strong> Latest LTS version</li>
                <li><strong>Docker:</strong> Latest CE version</li>
                <li><strong>Maven:</strong> 3.9.5</li>
                <li><strong>Git:</strong> Version control system</li>
                <li><strong>Node.js:</strong> v18.x</li>
            </ul>
        </div>

        <div class="info">
            <h3>🌐 Access Information</h3>
            <p><strong>Jenkins URL:</strong> <a href="http://INSTANCE_IP:8080" target="_blank">http://INSTANCE_IP:8080</a></p>
            <p><strong>Default Port:</strong> 8080</p>
            <p><strong>Service Status:</strong> <code>sudo systemctl status jenkins</code></p>
        </div>
    </div>
</body>
</html>
EOL

              # Replace INSTANCE_IP placeholder with actual IP
              INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
              sed -i "s/INSTANCE_IP/$INSTANCE_IP/g" /var/www/html/index.html

              EOF

  tags = {
    Name        = "Jenkins-Server"
    Environment = "Development"
    Project     = "Terraform-Demo"
    Service     = "Jenkins"
  }
}

# Outputs
output "tomcat_server_public_ip" {
  description = "Public IP address of Tomcat Server"
  value       = aws_instance.tomcat_server.public_ip
}

output "tomcat_server_public_dns" {
  description = "Public DNS name of Tomcat Server"
  value       = aws_instance.tomcat_server.public_dns
}

output "tomcat_url" {
  description = "Tomcat application URL"
  value       = "http://${aws_instance.tomcat_server.public_ip}:8080"
}

output "tomcat_test_app_url" {
  description = "Tomcat test application URL"
  value       = "http://${aws_instance.tomcat_server.public_ip}:8080/test"
}

output "maven_server_public_ip" {
  description = "Public IP address of Maven Server"
  value       = aws_instance.maven_server.public_ip
}

output "maven_server_public_dns" {
  description = "Public DNS name of Maven Server"
  value       = aws_instance.maven_server.public_dns
}

output "maven_info_url" {
  description = "Maven server info page URL"
  value       = "http://${aws_instance.maven_server.public_ip}"
}

output "jenkins_server_public_ip" {
  description = "Public IP address of Jenkins Server"
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_server_public_dns" {
  description = "Public DNS name of Jenkins Server"
  value       = aws_instance.jenkins_server.public_dns
}

output "jenkins_url" {
  description = "Jenkins application URL"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "jenkins_info_url" {
  description = "Jenkins server info page URL"
  value       = "http://${aws_instance.jenkins_server.public_ip}"
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.ec2_sg.id
}
