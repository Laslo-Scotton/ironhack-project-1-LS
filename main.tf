# --- Provide AWS ---
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
    region = var.base_region
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block = var.base_cidr_block

  tags = {
    Name = "Main LS"
  }
}

# --- Subnet ---
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr
  map_public_ip_on_launch = true
  # availability_zone       = var.subnet_region_a

  tags = {
    Name = "public-subnet-LS"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_private_cidr
  # availability_zone       = var.subnet_region_b

  tags = {
    Name = "private-subnet-LS"
  }
}

resource "aws_subnet" "private_subnet_db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_private_db_cidr
  # availability_zone       = var.subnet_region_b

  tags = {
    Name = "private-subnet-db-LS"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw-LS"
  }
}

# --- EIP ---
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
  tags = {
    Name = "nat-eip-LS"
  }
}

# --- NAT Gateway ---
resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet.id

  tags = {
    Name = "main-nat-LS"
  }
  depends_on = [aws_internet_gateway.main_igw]
}

# --- Route Tables ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public-rt-LS"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat.id
  }

  tags = {
    Name = "private-rt-LS"
  }
}

resource "aws_route_table" "private_db_rt" {
  vpc_id = aws_vpc.main.id

  # No Internet access for the DB route table
  # route {
  #   cidr_block = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.main_nat.id
  # }

  tags = {
    Name = "private-db-rt-LS"
  }
}

# --- Route Table Associations ---
resource "aws_route_table_association" "public_subnet_assoc_az1" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_assoc_az1" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_db_assoc_az1" {
  subnet_id      = aws_subnet.private_subnet_db.id
  route_table_id = aws_route_table.private_db_rt.id
}

# --- Security groups ---
# SG ALB
resource "aws_security_group" "sg_alb" {
  name = "secg-albg"
  vpc_id = aws_vpc.main.id
  
  ingress {
    description = "Allow HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# SG VOTE
resource "aws_security_group" "sg_vote" {
  name = "secg-vote"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow access from ALB Sg"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.sg_alb.id]
  }

  ingress {
    description = "Allow ssh from Bastion"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# SG RESULT
resource "aws_security_group" "sg_result" {
  name = "secg-result"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow access from ALB Sg"
    from_port = 8081
    to_port = 8081
    protocol = "tcp"
    security_groups = [aws_security_group.sg_alb.id]
  }

  ingress {
    description = "Allow ssh from Bastion"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# SG WORKER
resource "aws_security_group" "sg_worker" {
  name = "secg-worker"
  vpc_id = aws_vpc.main.id

  ingress {
      description = "Allow access from ALB Sg"
      from_port = 8081
      to_port = 8081
      protocol = "tcp"
      security_groups = [aws_security_group.sg_alb.id]
  }

  ingress {
    description = "Allow ssh from Bastion"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# SG REDIS
resource "aws_security_group" "sg_redis" {
  name   = "secg-redis"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [
      aws_security_group.sg_vote.id,
      aws_security_group.sg_worker.id
    ]
  }

  ingress {
    description = "Allow ssh from Bastion"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
}
# SG DB
resource "aws_security_group" "sg_db" {
  name   = "secg-db"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [
      aws_security_group.sg_result.id,
      aws_security_group.sg_worker.id
    ]
  }

  ingress {
    description = "Allow ssh from Bastion"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }
}
# SG BASTION
resource "aws_security_group" "sg_bastion" {
  name   = "secg-bastion"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
}

# --- Load Balancer ---
resource "aws_lb" "alb" {
  name = "alb-ls"
  internal = false
  load_balancer_type = "application"
  subnets = [aws_subnet.public_subnet.id] # here also put other subnets when multi az
  security_groups = [aws_security_group.sg_alb.id]

  tags = {
    Name = "alb-LS"
  }
}

# --- Load Balancer Target Group ---
resource "aws_lb_target_group" "tg_vote" {
  name     = "tg-vote"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/health"
  }
}

resource "aws_lb_target_group" "tg_result" {
  name     = "tg-vote"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/health"
  }
}

# --- Load Balancer Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "no matching rule"
      status_code = "404"
    }
  }
}

# --- Load Balancer Listener Rules ---
resource "aws_lb_listener_rule" "vote_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority = 20

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg_vote.arn
  }

  condition {
    path_pattern {
      values = ["/vote*"]
    }
  }
}

resource "aws_lb_listener_rule" "result_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority = 40

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg_result.arn
  }

  condition {
    path_pattern {
      values = ["/result*"]
    }
  }
}

# --- Instances ---
# Bastion
resource "aws_instance" "bastion" {
  ami = var.ami_id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_bastion.id]
  key_name = var.access_key
}

