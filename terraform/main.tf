terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = var.aws_region
}
data "aws_availability_zones" "available" {
  state = "available"
}
# Use the latest available Amazon Linux 2 AMI.
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_vpc" "startuptech" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "startuptech-vpc" }
}
# Public subnets: Bastion, NAT Gateway and ALB.
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.startuptech.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "startuptech-public-1" }
}
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.startuptech.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "startuptech-public-2" }
}
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.startuptech.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "startuptech-private-1" }
}
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.startuptech.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "startuptech-private-2" }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.startuptech.id
  tags   = { Name = "startuptech-igw" }
}
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "startuptech-nat-eip" }
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "startuptech-nat" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.startuptech.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "startuptech-public-rt" }
}
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.startuptech.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "startuptech-private-rt" }
}
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
# ALB receives web traffic from the internet.
resource "aws_security_group" "alb" {
  name   = "startuptech-alb-sg"
  vpc_id = aws_vpc.startuptech.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS allowed; TLS listener is not part of this assessment"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "startuptech-alb-sg" }
}
resource "aws_security_group" "bastion" {
  name   = "startuptech-bastion-sg"
  vpc_id = aws_vpc.startuptech.id
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.my_ip
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "startuptech-bastion-sg" }
}
resource "aws_security_group" "backend" {
  name   = "startuptech-backend-sg"
  vpc_id = aws_vpc.startuptech.id
  ingress {
    description     = "API traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "startuptech-backend-sg" }
}
resource "aws_security_group" "mongodb" {
  name   = "startuptech-mongodb-sg"
  vpc_id = aws_vpc.startuptech.id
  ingress {
    description     = "MongoDB from backend only"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "startuptech-mongodb-sg" }
}
# Register thisSSH public key with AWS
resource "aws_key_pair" "assessment" {
  key_name   = var.key_name
  public_key = file(pathexpand("~/.ssh/my-assessment-key.pub"))

  tags = {
    Name = "startuptech-keypair"
  }
}
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.assessment.key_name
  tags                        = { Name = "startuptech-bastion" }
}
resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id
  tags     = { Name = "startuptech-bastion-eip" }
}
resource "aws_instance" "backend" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.backend_instance_type
  subnet_id                   = aws_subnet.private_1.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.assessment.key_name
  user_data                   = file("${path.module}/user_data/backend_setup.sh")
  depends_on                  = [aws_route_table_association.private_1]
  tags                        = { Name = "startuptech-backend" }
}
resource "aws_instance" "mongodb" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.mongodb_instance_type
  subnet_id                   = aws_subnet.private_2.id
  vpc_security_group_ids      = [aws_security_group.mongodb.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.assessment.key_name
  user_data                   = file("${path.module}/user_data/mongodb_setup.sh")
  depends_on                  = [aws_route_table_association.private_2]
  tags                        = { Name = "startuptech-mongodb" }
}
resource "aws_lb" "backend" {
  name               = "startuptech-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  tags               = { Name = "startuptech-alb" }
}
resource "aws_lb_target_group" "backend" {
  name     = "startuptech-backend-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.startuptech.id
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
resource "aws_lb_target_group_attachment" "backend" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend.id
  port             = 8080
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
