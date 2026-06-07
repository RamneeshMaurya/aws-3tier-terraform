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

# 1. Web Layer ke liye Security Group (Firewall)
resource "aws_security_group" "web_sg" {
  name        = "web-layer-sg"
  description = "Allow HTTP traffic from internet"
  vpc_id      = aws_vpc.main.id

  # Internet se HTTP (Port 80) allow karein
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic (Server ko bahar connect karne ke liye)
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