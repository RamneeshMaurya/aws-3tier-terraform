# 1. Main Network (VPC)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "3Tier-VPC" }
}

# Internet Gateway (Internet se jodne ke liye)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "Main-IGW" }
}

# 2. LAYER 1: Public Web Subnet (Presentation Layer)
resource "aws_subnet" "public_web" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "Web-Layer-Public" }
}

# 3. LAYER 2: Private App Subnet (Application Layer)
resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "App-Layer-Private" }
}

# 4. LAYER 3: Isolated Database Subnet (Data Layer)
resource "aws_subnet" "private_db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "DB-Layer-Isolated" }
}

# =======================================================
# BAAKI KA 50% KAAM: SECURITY GROUPS & COMPUTE (SERVERS)
# =======================================================

# 1. Web Layer ke liye Security Group (FIXED)
resource "aws_security_group" "web_sg" {
  name        = "web-layer-sg"
  description = "Allow HTTP traffic from internet and Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Rule 1: Internet se HTTP allow karein
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CRUCIAL FIX: Load Balancer ko instances ke andar aane ki permission dein
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # LB ka group allow kiya
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Web-Layer-SG" }
}

# 2. App Layer ke liye Security Group (SECURE: Sirf Web SG se traffic aayega)
resource "aws_security_group" "app_sg" {
  name        = "app-layer-sg"
  description = "Allow traffic only from Web SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080 # App generally 8080 par chalti hai
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # SECURE LAYER!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "App-Layer-SG" }
}

# 3. Web Layer me ek Real EC2 Server (Presentation Layer)
resource "aws_instance" "web_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS (us-east-1)
  instance_type = "t3.micro"             # Free Tier eligible
  subnet_id     = aws_subnet.public_web.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = { Name = "3Tier-Web-Server" }
}

# 4. App Layer me ek Real EC2 Server (Application Logic Layer)
resource "aws_instance" "app_server" {
  ami           = "ami-0c7217cdde317cfec" 
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private_app.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = { Name = "3Tier-App-Server" }
}
# =======================================================
# FINAL 20% KAAM: LOAD BALANCER & AUTO SCALING
# =======================================================

# 1. Load Balancer ke liye Public Security Group
resource "aws_security_group" "lb_sg" {
  name        = "load-balancer-sg"
  vpc_id      = aws_vpc.main.id

  # Internet se HTTP (Port 80) allow karein
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

# 2. Application Load Balancer (ALB) Create Karna
resource "aws_lb" "web_alb" {
  name               = "3tier-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_web.id, aws_subnet.public_web_2.id] # Multi-AZ public access ke liye

  tags = { Name = "3Tier-Web-ALB" }
}

# 3. ALB Target Group (Jahan ASG naye servers ko jodega)
resource "aws_lb_target_group" "web_tg" {
  name     = "3tier-web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

# 4. ALB Listener (Jo incoming traffic ko sunega aur Target Group par bhejega)
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 5. ASG Launch Template (Naye servers ka blueprint - Ubuntu + t3.micro)
resource "aws_launch_template" "web_lt" {
  name_prefix   = "3tier-web-template-"
  image_id      = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS us-east-1
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  # Ek chota sa script jo server on hote hi Apache (Web Server) install kar dega
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install apache2 -y
              systemctl start apache2
              systemctl enable apache2
              echo "<h1>Welcome to My Scalable 3-Tier Architecture!</h1>" > /var/www/html/index.html
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

# 6. Auto Scaling Group (ASG) - Jo minimum 1 aur maximum 3 servers manage karega
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 2 # Hamesha 2 servers live chalte rahenge
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
# Ek naya Public Subnet 2 (Alag Availability Zone 'us-east-1b' me)
resource "aws_subnet" "public_web_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24" # Naya IP range
  availability_zone = "us-east-1b"   # ALAG ZONE!
  map_public_ip_on_launch = true

  tags = { Name = "3Tier-Public-Web-2" }
}