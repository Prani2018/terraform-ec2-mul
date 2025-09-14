#!/bin/bash

# Redirect all output to a log file
exec > >(tee ${log_file}) 2>&1

echo "=== Starting Tomcat installation at $(date) ==="

# Update system
apt-get update -y
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to update system packages"
    exit 1
fi

# Install Java and dependencies
apt-get install -y openjdk-11-jdk wget curl
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Java and dependencies"
    exit 1
fi

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /etc/environment
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/environment

echo "Java installed successfully: $(java -version)"

# Create tomcat user
useradd -m -U -d /opt/tomcat -s /bin/false tomcat
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create tomcat user"
    exit 1
fi

# Download and install Tomcat 10
cd /tmp
wget -q https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.15/bin/apache-tomcat-10.1.15.tar.gz
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download Tomcat"
    exit 1
fi

tar -xf apache-tomcat-10.1.15.tar.gz -C /opt/tomcat --strip-components=1
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to extract Tomcat"
    exit 1
fi

# Set permissions
chown -R tomcat: /opt/tomcat
chmod +x /opt/tomcat/bin/*.sh

echo "Tomcat extracted and permissions set"

# Create systemd service file
cat > /etc/systemd/system/tomcat.service << 'EOF'
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
EOF

# Reload systemd and start Tomcat
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat

# Wait for Tomcat to start
sleep 15

# Check if Tomcat is running
if systemctl is-active --quiet tomcat; then
    echo "Tomcat service started successfully"
else
    echo "ERROR: Tomcat service failed to start"
    systemctl status tomcat
    exit 1
fi

# Create test application directory
mkdir -p /opt/tomcat/webapps/test

# Create a simple test page
cat > /opt/tomcat/webapps/test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Tomcat Server - Test Page</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(31,38,135,0.37);
        }
        h1 { text-align: center; margin-bottom: 30px; }
        .info { 
            background: rgba(255,255,255,0.2); 
            padding: 20px; 
            margin: 15px 0; 
            border-radius: 8px; 
        }
        .success { color: #4CAF50; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Welcome to Tomcat Server!</h1>
        <div class="info">
            <h3>Server Information</h3>
            <p>This is the Tomcat EC2 instance configured via Terraform.</p>
            <p class="success">✅ Tomcat is running successfully on port 8080</p>
        </div>
        <div class="info">
            <h3>Access Points</h3>
            <ul>
                <li><strong>Manager App:</strong> /manager/html</li>
                <li><strong>Host Manager:</strong> /host-manager/html</li>
                <li><strong>Test App:</strong> /test (this page)</li>
            </ul>
        </div>
        <div class="info">
            <h3>Server Details</h3>
            <p><strong>Java Version:</strong> OpenJDK 11</p>
            <p><strong>Tomcat Version:</strong> 10.1.15</p>
            <p><strong>Installation Time:</strong> $(date)</p>
        </div>
    </div>
</body>
</html>
EOF

# Set proper ownership
chown -R tomcat:tomcat /opt/tomcat/webapps/test

echo "Test application created successfully"

# Create a status check script
cat > /home/ubuntu/check-tomcat.sh << 'EOF'
#!/bin/bash
echo "=== Tomcat Status Check ==="
echo "Service Status:"
systemctl status tomcat --no-pager

echo -e "\nJava Processes:"
ps aux | grep java

echo -e "\nPort 8080 Status:"
netstat -tlnp | grep :8080

echo -e "\nTomcat Logs (last 20 lines):"
tail -n 20 /opt/tomcat/logs/catalina.out 2>/dev/null || echo "No catalina.out found"

echo -e "\nTest Application Access:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080/test/ || echo "Failed to connect"
EOF

chmod +x /home/ubuntu/check-tomcat.sh
chown ubuntu:ubuntu /home/ubuntu/check-tomcat.sh

echo "=== Tomcat installation completed successfully at $(date) ==="
echo "=== You can check status with: sudo /home/ubuntu/check-tomcat.sh ==="
