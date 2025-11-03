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
  vpc = true
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
    name = "sg-albg"
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
    name = "sg-vote"
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
}
# SG RESULT
resource "aws_security_group" "sg_result" {
    name = "sg-result"
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
}
# SG WORKER
resource "aws_security_group" "sg_worker" {
    name = "sg-worker"
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
}
# SG REDIS
resource "aws_security_group" "sg_redis" {
  name   = "sg-redis"
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
  name   = "sg-db"
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
  name   = "sg-bastion"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]
  }
}











# --- Instances ---
resource "aws_instance" "nginx_instances" {
    count = 2
    ami = aws_ami_from_instance.nginx_ami.id
    instance_type = "t3.micro"
    subnet_id = element([aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id], count.index)
    vpc_security_group_ids = [aws_security_group.web_sg.id]
    key_name = "LS-AWS-IronhackKey"
    associate_public_ip_address = true


    tags = {
        Name = "nginx-instance-LS-${count.index + 1}"
    }
}

# Create the lb target group
resource "aws_lb_target_group" "web_tg" {
    name = "nginx-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id

    health_check {
        path = "/"
        port = "80"
    }
}

# Attach the instances to target group
resource "aws_lb_target_group_attachment" "web_tg_attachment" {
    count = length(aws_instance.nginx_instances)
    target_group_arn = aws_lb_target_group.web_tg.arn
    target_id = aws_instance.nginx_instances[count.index].id
    port = 80
}

# Create the LB
resource "aws_lb" "web_lb" {
    name = "nginx-lb"
    load_balancer_type = "application"
    subnets = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
    security_groups = [aws_security_group.web_sg.id]
}

#Listener to route HTTP traffic
resource "aws_lb_listener" "web_listener" {
    load_balancer_arn = aws_lb.web_lb.arn
    port = 80
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.web_tg.arn
    }
}

