#!/bin/bash

# Redirect all output to a log file
exec > >(tee ${log_file}) 2>&1

echo "=== Starting Maven installation at $(date) ==="

# Update system
apt-get update -y
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to update system packages"
    exit 1
fi

# Install Java and dependencies
apt-get install -y openjdk-11-jdk wget curl git apache2
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install dependencies"
    exit 1
fi

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /etc/environment
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/environment

echo "Java installed successfully: $(java -version)"

# Download and install Maven
cd /opt
wget -q https://archive.apache.org/dist/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download Maven"
    exit 1
fi

tar -xzf apache-maven-3.9.5-bin.tar.gz
mv apache-maven-3.9.5 maven

# Set Maven environment variables
export M2_HOME=/opt/maven
export MAVEN_HOME=/opt/maven
export PATH=/opt/maven/bin:$PATH

echo 'export M2_HOME=/opt/maven' >> /etc/environment
echo 'export MAVEN_HOME=/opt/maven' >> /etc/environment
echo 'export PATH=/opt/maven/bin:$PATH' >> /etc/environment

# Create symbolic links
ln -sf /opt/maven/bin/mvn /usr/local/bin/mvn

echo "Maven installed successfully: $(mvn -version)"

# Start and enable Apache
systemctl start apache2
systemctl enable apache2

if systemctl is-active --quiet apache2; then
    echo "Apache2 started successfully"
else
    echo "ERROR: Apache2 failed to start"
    exit 1
fi

# Create info page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Maven Build Server</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 0;
            background: linear-gradient(135deg, #74b9ff 0%, #0984e3 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #6c5ce7 0%, #a29bfe 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .content {
            padding: 40px;
        }
        .info { 
            background-color: #f8f9fa; 
            padding: 20px; 
            margin: 20px 0; 
            border-radius: 8px; 
            border-left: 5px solid #6c5ce7;
        }
        .success { 
            background-color: #d4edda; 
            border-left-color: #28a745;
            color: #155724;
        }
        ul li { margin: 10px 0; }
        code { 
            background: #f4f4f4; 
            padding: 4px 8px; 
            border-radius: 4px; 
            font-family: 'Courier New', monospace;
            font-size: 14px;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin: 20px 0;
        }
        @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛠️ Maven Build Server</h1>
            <p>Ubuntu 22.04 LTS configured with Maven for Java project builds</p>
        </div>
        
        <div class="content">
            <div class="success info">
                <h3>✅ Installation Complete</h3>
                <p>Maven build server is ready for Java development and CI/CD pipelines!</p>
            </div>

            <div class="grid">
                <div class="info">
                    <h3>📦 Installed Software</h3>
                    <ul>
                        <li><strong>OS:</strong> Ubuntu 22.04 LTS</li>
                        <li><strong>Java:</strong> OpenJDK 11</li>
                        <li><strong>Maven:</strong> 3.9.5</li>
                        <li><strong>Git:</strong> Version control</li>
                        <li><strong>Apache:</strong> Web server</li>
                    </ul>
                </div>

                <div class="info">
                    <h3>🔧 Environment Variables</h3>
                    <p><strong>JAVA_HOME:</strong><br><code>/usr/lib/jvm/java-11-openjdk-amd64</code></p>
                    <p><strong>MAVEN_HOME:</strong><br><code>/opt/maven</code></p>
                    <p><strong>M2_HOME:</strong><br><code>/opt/maven</code></p>
                </div>
            </div>

            <div class="info">
                <h3>🚀 Quick Start</h3>
                <p>SSH into this instance and try these commands:</p>
                <p><code>mvn --version</code> - Verify Maven installation</p>
                <p><code>java -version</code> - Verify Java installation</p>
                <p><code>cd /home/ubuntu/projects/sample-project && mvn compile</code> - Build sample project</p>
                <p><code>cd /home/ubuntu/projects/sample-project && mvn test</code> - Run tests</p>
            </div>

            <div class="info">
                <h3>📁 Sample Project</h3>
                <p>A sample Maven project has been created at:</p>
                <p><code>/home/ubuntu/projects/sample-project</code></p>
                <p>This includes a simple HelloWorld application with JUnit tests.</p>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Create sample Maven project structure
echo "Creating sample Maven project..."
mkdir -p /home/ubuntu/projects/sample-project/src/main/java/com/example
mkdir -p /home/ubuntu/projects/sample-project/src/test/java/com/example

# Create pom.xml
cat > /home/ubuntu/projects/sample-project/pom.xml << 'EOF'
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
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Create Java source files
cat > /home/ubuntu/projects/sample-project/src/main/java/com/example/HelloWorld.java << 'EOF'
package com.example;

public class HelloWorld {
    public static void main(String[] args) {
        HelloWorld hw = new HelloWorld();
        System.out.println(hw.getMessage());
    }
    
    public String getMessage() {
        return "Hello from Maven Build Server!";
    }
    
    public String getServerInfo() {
        return "Maven 3.9.5 with OpenJDK 11 on Ubuntu 22.04";
    }
}
EOF

# Create test class
cat > /home/ubuntu/projects/sample-project/src/test/java/com/example/HelloWorldTest.java << 'EOF'
package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

public class HelloWorldTest {
    
    @Test
    public void testGetMessage() {
        HelloWorld hw = new HelloWorld();
        assertEquals("Hello from Maven Build Server!", hw.getMessage());
    }
    
    @Test
    public void testGetServerInfo() {
        HelloWorld hw = new HelloWorld();
        String info = hw.getServerInfo();
        assertTrue("Server info should contain Maven", info.contains("Maven"));
        assertTrue("Server info should contain OpenJDK", info.contains("OpenJDK"));
    }
}
EOF

# Set ownership for all project files
chown -R ubuntu:ubuntu /home/ubuntu/projects

# Create a build script for easy testing
cat > /home/ubuntu/build-sample.sh << 'EOF'
#!/bin/bash
echo "=== Building Sample Maven Project ==="
cd /home/ubuntu/projects/sample-project

echo "Compiling..."
mvn clean compile

echo "Running tests..."
mvn test

echo "Creating JAR..."
mvn package

echo "=== Build Complete ==="
echo "JAR file location: target/sample-project-1.0-SNAPSHOT.jar"
echo "Run with: java -cp target/sample-project-1.0-SNAPSHOT.jar com.example.HelloWorld"
EOF

chmod +x /home/ubuntu/build-sample.sh
chown ubuntu:ubuntu /home/ubuntu/build-sample.sh

echo "=== Maven installation completed successfully at $(date) ==="
echo "=== Sample project available at /home/ubuntu/projects/sample-project ==="
echo "=== Run /home/ubuntu/build-sample.sh to test the Maven setup ==="
