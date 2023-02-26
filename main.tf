terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
    }
  }
}
variable "aws_region" {
  type = string
}
variable "tag_name" {
  type = string
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Name = var.tag_name
    }
  }
}


# ==========================================================
# ====================== Networking ========================
# ==========================================================
# Define VPC for cluster
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}
# Create subnet with IP address range long enough to accommodate all nodes in cluster
resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  # host up to 254 compute instances
  cidr_block = "10.0.1.0/24"

}
# Configure and attach Internet Gateway for cluster
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
# Configure Route Tables for cluster and Gateway
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Configure security groups, or firewall rules
resource "aws_security_group" "inbound" {
  name        = var.tag_name
  vpc_id      = aws_vpc.main.id
  description = "Kubernetes security group"

  ingress {
    protocol    = "-1"
    description = "Allow all internal communication for all protocols"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["10.0.0.0/16", "10.200.0.0/16"]
  }
  ingress {
    protocol    = "tcp"
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    description = "Allow https 6443"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    description = "Allow https 443"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "icmp"
    description = "Allow ICMP aka ping"
    from_port   = 1
    to_port     = 1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# "Target groups route requests to one or more registered targets"
# Create load balancer target group
resource "aws_lb_target_group" "main" {
  name        = var.tag_name
  port        = 6443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
}
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = "10.0.1.10"
}

# Create network load balancer to help public access to cluster
resource "aws_lb" "main" {
  name               = var.tag_name
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.main.id]
}
resource "aws_lb_listener" "forward" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
# ==========================================================
# =================== Compute Instances ====================
# ==========================================================
# Using Ubuntu Server 20.04, which has good support for the containerd container runtime.
# Each compute instance will get a fixed private IP address to simplify bootstrapping
data "aws_ami" "ubuntu" {
  # Canonical owner
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Generate keys to allow SSH access to instances
#! Having Terraform generate the key is not secure for production
resource "tls_private_key" "dev" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "deployer" {
  key_name   = "${var.tag_name}-key"
  public_key = tls_private_key.dev.public_key_openssh
}
resource "local_sensitive_file" "private_key" {
  content  = tls_private_key.dev.private_key_pem
  filename = "${var.tag_name}-private.pem"
}

# Create 3 instance for k8s control nodes
resource "aws_instance" "controller" {
  count = 3

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.inbound.id]
  associate_public_ip_address = true
  user_data                   = "name=controller-${count.index}"
  subnet_id                   = aws_subnet.main.id
  source_dest_check           = false
  private_ip                  = "10.0.1.1${count.index}"

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }

  tags = {
    Id = "controller-${count.index}"
  }
}

# Create 3 instance for k8s worker nodes
resource "aws_instance" "worker" {
  count = 3

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.inbound.id]
  associate_public_ip_address = true
  user_data                   = "name=worker-${count.index}|pod-cidr=10.200.${count.index}.0/24"
  subnet_id                   = aws_subnet.main.id
  source_dest_check           = false
  private_ip                  = "10.0.1.2${count.index}"

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }

  tags = {
    Id = "worker-${count.index}"
  }
}
