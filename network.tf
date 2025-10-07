# -----------------------------------------------------------------------------
# VPC: The Core Network
# -----------------------------------------------------------------------------
resource "aws_vpc" "app_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.app_name}-VPC"
  }
}

# -----------------------------------------------------------------------------
# Subnets and Availability Zones (AZs)
# -----------------------------------------------------------------------------
# Data source to fetch all Availability Zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Public Subnets (for Load Balancer, NAT Gateway)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true # Public subnets must auto-assign IPs
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.app_name}-Public-Subnet-${count.index + 1}"
  }
}

# Create Private Subnets (for RDS, ECS Fargate)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.app_name}-Private-Subnet-${count.index + 1}"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway (IGW) and Routing for Public Subnets
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "${var.app_name}-IGW"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    # Send all internet-bound traffic (0.0.0.0/0) to the IGW
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.app_name}-Public-Route-Table"
  }
}

# Associate the public route table with the public subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# NAT Gateway and Routing for Private Subnets
# -----------------------------------------------------------------------------
# 1. Allocate an Elastic IP (EIP) for the NAT Gateway
resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.igw] # Ensure IGW exists before EIP is attached

  tags = {
    Name = "${var.app_name}-NAT-EIP"
  }
}

# 2. Create the NAT Gateway in the FIRST public subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place the NAT GW in one of the public subnets

  tags = {
    Name = "${var.app_name}-NAT-Gateway"
  }
}

# 3. Create a Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    # Send all internet-bound traffic (0.0.0.0/0) to the NAT Gateway
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.app_name}-Private-Route-Table"
  }
}

# 4. Associate the private route table with the private subnets
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# OUTPUTS (Critical for future files)
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.app_vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = [for s in aws_subnet.private : s.id]
}
