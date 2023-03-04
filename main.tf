terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
    }
  }
}
variable "AWS_REGION" {
  type = string
}
variable "TAG_NAME" {
  type = string
}
variable "CLUSTER_IP_START" {
  type = string
}
variable "POD_CIDR_PREFIX" {
  type = string
}
provider "aws" {
  region = var.AWS_REGION
  default_tags {
    tags = {
      Name = var.TAG_NAME
    }
  }
}

# ==========================================================
# ====================== Networking ========================
# ==========================================================
# Define VPC for cluster
resource "aws_vpc" "main" {
  cidr_block           = "${var.CLUSTER_IP_START}.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
}
# Create subnet with IP address range long enough to accommodate all nodes in cluster
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "${var.CLUSTER_IP_START}.0/24"
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
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Create route per worker node.
# This requires the network_interface_id which must be fetched from the data source.
data "aws_instance" "worker" {
  for_each    = toset(aws_instance.worker.*.id)
  instance_id = each.key
}
# Create map of network IDs to CIDR blocks for each for_each use later.
locals {
  worker_route_info = zipmap(
    [for val in data.aws_instance.worker : val.network_interface_id],
  [for i in range(3) : "${var.POD_CIDR_PREFIX}.${i}.0/24"])
}
# Configure routes between Pods
resource "aws_route" "private" {
  for_each = local.worker_route_info

  route_table_id         = aws_route_table.main.id
  destination_cidr_block = each.value
  network_interface_id   = each.key

  depends_on = [
    aws_instance.worker
  ]
}

# Configure security groups, or firewall rules
resource "aws_security_group" "inbound" {
  name        = var.TAG_NAME
  vpc_id      = aws_vpc.main.id
  description = "Kubernetes security group"

  ingress {
    protocol    = "-1"
    description = "Allow all internal communication for all protocols"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.CLUSTER_IP_START}.0/24", "${var.POD_CIDR_PREFIX}.0.0/16"]
  }
  ingress {
    protocol    = "tcp"
    description = "Allow SSH"
    from_port   = 0
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    description = "Allow https 6443"
    from_port   = 0
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    description = "Allow https 443"
    from_port   = 0
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "icmp"
    description = "Allow ICMP aka ping"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  # A default Egress rules that AWS puts but Terraform removes unless we set it back
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# "Target groups route requests to one or more registered targets"
# Create load balancer target group
resource "aws_lb_target_group" "main" {
  name        = var.TAG_NAME
  port        = 6443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    protocol = "HTTP"
    port     = 80
    path     = "/healthz"
  }
}
resource "aws_lb_target_group_attachment" "main" {
  count            = 3
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = "${var.CLUSTER_IP_START}.1${count.index}"
}

# Create network load balancer to help public access to cluster
resource "aws_lb" "main" {
  name               = var.TAG_NAME
  internal           = false
  load_balancer_type = "network"
  # subnets            = [aws_subnet.main.id]
  subnet_mapping {
    subnet_id     = aws_subnet.main.id
    allocation_id = aws_eip.main.allocation_id
  }
}
resource "aws_lb_listener" "forward" {
  load_balancer_arn = aws_lb.main.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_eip" "main" {
  vpc = true

  depends_on = [aws_internet_gateway.main]
}

resource "local_file" "eip_address" {
  content  = aws_eip.main.public_ip
  filename = "k8s-public-address"
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
  key_name   = "${var.TAG_NAME}-key"
  public_key = tls_private_key.dev.public_key_openssh
}
resource "local_sensitive_file" "private_key" {
  content  = tls_private_key.dev.private_key_pem
  filename = "${var.TAG_NAME}-private.pem"
}

# Create 3 instance for k8s control nodes
resource "aws_instance" "controller" {
  count = 3

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.inbound.id]
  associate_public_ip_address = true
  user_data                   = "name=controller-${count.index}"
  subnet_id                   = aws_subnet.main.id
  source_dest_check           = false
  private_ip                  = "${var.CLUSTER_IP_START}.1${count.index}"

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
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.inbound.id]
  associate_public_ip_address = true
  user_data                   = "name=worker-${count.index}|pod-cidr=10.200.${count.index}.0/24"
  subnet_id                   = aws_subnet.main.id
  source_dest_check           = false
  private_ip                  = "${var.CLUSTER_IP_START}.2${count.index}"

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }

  tags = {
    Id = "worker-${count.index}"
  }
}
