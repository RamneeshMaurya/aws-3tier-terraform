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