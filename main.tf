# 2. VPC Creation
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "3Tier-VPC" }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "3Tier-IGW" }
}

# 4. Public Subnet 1 (AZ: us-east-1a)
resource "aws_subnet" "public_web" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "3Tier-Public-Web-1" }
}

# 5. Public Subnet 2 (AZ: us-east-1b) - CRUCIAL FOR ALB
resource "aws_subnet" "public_web_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "3Tier-Public-Web-2" }
}

# 6. Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "3Tier-Public-RT" }
}

# 7. Route Table Associations (Dono subnets ko Internet se joda)
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_web.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_web_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# SECURITY GROUPS & LOAD BALANCER
# ==========================================

# 8. Load Balancer Security Group
resource "aws_security_group" "lb_sg" {
  name   = "load-balancer-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "3Tier-LB-SG" }
}

# 9. Web Instances Security Group
resource "aws_security_group" "web_sg" {
  name   = "web-layer-sg-final"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "3Tier-Web-SG" }
}

# 10. Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = "3tier-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_web.id, aws_subnet.public_web_2.id]
  tags               = { Name = "3Tier-Web-ALB" }
}

# 11. Target Group
resource "aws_lb_target_group" "web_tg" {
  name     = "3tier-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 20
  }
}

# 12. ALB Listener
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ==========================================
# AUTO SCALING
# ==========================================

# 13. ASG Launch Template
resource "aws_launch_template" "web_lt" {
  name_prefix   = "3tier-web-lt-"
  image_id      = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS us-east-1
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "<h1>Welcome to My Scalable 3-Tier Architecture!</h1>" | sudo tee /var/www/html/index.html
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

# 14. Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.web_tg.arn]
  vpc_zone_identifier = [aws_subnet.public_web.id, aws_subnet.public_web_2.id]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ASG-Web-Server"
    propagate_at_launch = true
  }
}
# ==========================================
# DATABASE TIER (RDS REGION - CONTINUING AFTER AUTOSCALING)
# ==========================================

# 15. Private Subnet 1 for DB (AZ: us-east-1a)
resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "3Tier-Private-DB-1" }
}

# 16. Private Subnet 2 for DB (AZ: us-east-1b)
resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "3Tier-Private-DB-2" }
}

# 17. RDS Subnet Group (NAME FIXED TO PLAIN TEXT)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "dbsubnet"
  subnet_ids = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]
  tags       = { Name = "3Tier-DB-Subnet-Group" }
}

# 18. Database Security Group (Tight Security Firewall)
resource "aws_security_group" "db_sg" {
  name        = "db-layer-sg"
  description = "Allow MySQL traffic ONLY from Web Servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Sirf web_sg allowed hai
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "3Tier-DB-SG" }
}

# 19. AWS RDS MySQL Database Instance
resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "threetierdb"
  username               = "admin"
  password               = "SuperSecretPassword123"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = { Name = "3Tier-MySQL-Database" }
}