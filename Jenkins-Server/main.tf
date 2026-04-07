#create a vpc for your instances
resource "aws_vpc" "main" {
  cidr_block = cidrsubnet("10.0.0.0/8", 8, length(data.aws_availability_zones.available.names))

  tags = {
    Name = var.Name
  }
}

#create internet gateway for your vpc
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.Name
  }
}

#create public subnets in two availability zones
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

#create private subnets in two availability zones
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

#create a route table for your public subnet
resource "aws_route_table" "public" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#create a route table for your private subnet
resource "aws_route_table" "private" {
  count  = 2 
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
}

#associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

#associate the route table with the private subnet
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#create aws availability zones
data "aws_availability_zones" "available" {}

#create elastic ip for nat gateway
resource "aws_eip" "nat" {
  count = 2
  domain = "vpc"
}

# EIPs for EC2 instances (separate)
resource "aws_eip" "ec2" {
  count  = 2
  domain = "vpc"
}


#create NAT Gateway for private subnet in public subnet
resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}

# fixed: added count, indexed both instance and eip, removed nat eip conflict
resource "aws_eip_association" "eip_assoc" {
  count         = 2
  instance_id   = aws_instance.example[count.index].id
  allocation_id = aws_eip.ec2[count.index].id  # WARNING: see note below
}

#create a loadbalancer for high availability multizone
resource "aws_lb" "app_lb" {
  name               = var.name
  load_balancer_type = var.load_balancer_type
  subnets            = aws_subnet.public[*].id
}

#create a load balancer target group
resource "aws_lb_target_group" "tg" {
  name     = var.lb_target_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

#create a load balancer listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80

  default_action {
    type             = "forward"  # fixed: was "foward" (typo)
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

#create launch template for auto scaling
resource "aws_launch_template" "app_launch_template" {
  name          = var.name_template
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
}

#create auto scaling group
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 2
  max_size            = 2
  min_size            = 2
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }
}

#create aws AMI data source
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

#create EC2 instances
resource "aws_instance" "example" {
  count                  = 2  # fixed: changed to 2 to match subnet count
  ami                    = data.aws_ami.ubuntu.id
  availability_zone      = data.aws_availability_zones.available.names[count.index]
  subnet_id              = aws_subnet.public[count.index].id
  instance_type          = "m7i-flex.large"
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]
  user_data              = file("${path.module}/setup.sh")
}

#create security group
resource "aws_security_group" "sg" {
  name        = "allow_http"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#generate private key
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-terraform-key"
  public_key = tls_private_key.example.public_key_openssh
}

#save private key locally
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/my-terraform-key.pem"
  file_permission = "0600"
}