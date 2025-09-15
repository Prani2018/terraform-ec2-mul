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

locals {
  servers = {
    tomcat_server = {
      user_data_path = "${path.module}/scripts/tomcat-userdata.sh"
      script_vars    = { log_file = "/var/log/tomcat-init.log" }
    },
    maven_server = {
      user_data_path = "${path.module}/scripts/maven-userdata.sh"
      script_vars    = { log_file = "/var/log/maven-init.log" }
    },
    jenkins_server = {
      user_data_path = "${path.module}/scripts/jenkins-userdata.sh"
      script_vars = {
        log_file = "/var/log/jenkins-init.log"
      }
    }
  }
}

# EC2 Instance 1 - Tomcat Server
resource "aws_instance" "servers" {
  for_each = local.servers	

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  #subnet_id             = var.create_vpc ? aws_subnet.public[0].id : data.aws_subnet.default[0].id
  subnet_id              = data.aws_subnet.default.id   # ✅ FIXED: no reference to undeclared aws_subnet.public
  user_data = templatefile(each.value.user_data_path, each.value.script_vars)
  tags = {
    Name        = each.key
    Environment = "Development"
    Project     = "TF-ec2-mul"
    Service     = title(each.key)
  }
}



# Outputs
output "tomcat_server_public_ip" {
  description = "Public IP address of Tomcat Server"
  value       = aws_instance.servers["tomcat_server"].public_ip
}

