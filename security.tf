# -----------------------------------------------------------------------------
# RDS Security Group (Most Restrictive)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.app_name}-RDS-SG"
  description = "Allows traffic only from the Spring Boot API containers (ECS Fargate)."
  vpc_id      = aws_vpc.app_vpc.id # Assumes you are using the output from network.tf

  # No ingress rule here yet. We will add it later using the Backend SG ID.

  # Egress: Allow outbound connections to anywhere.
  # This is usually needed for patching/updates, but strictly for DBs, you could restrict.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-RDS-SG"
  }
}

# -----------------------------------------------------------------------------
# Backend (Spring Boot/ECS Fargate) Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "backend" {
  name        = "${var.app_name}-Backend-SG"
  description = "Allows traffic from ALB and connects to RDS."
  vpc_id      = aws_vpc.app_vpc.id

  # Egress 1: Allow outbound to the RDS Security Group on the Postgres port (5432)
  egress {
    description = "Allow Postgres traffic to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.rds.id] # Target the RDS SG
  }

  # Egress 2: Allow all other outbound traffic (for external APIs, updates, etc. via NAT Gateway)
  egress {
    description = "Allow all outbound over NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # This rule is necessary for connecting to ECR/ECS control plane
    # and fetching code/secrets.
  }

  tags = {
    Name = "${var.app_name}-Backend-SG"
  }
}


# -----------------------------------------------------------------------------
# Ingress Rule for RDS (Self-Referencing)
# -----------------------------------------------------------------------------
# We create the SG first, then define the ingress rule that references the Backend SG.
resource "aws_security_group_rule" "rds_ingress" {
  description              = "Allow traffic from the Spring Boot containers"
  type                     = "ingress"
  from_port                = 5432 # Postgres Port
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.backend.id # ONLY from the backend SG
}

# -----------------------------------------------------------------------------
# ALB (Application Load Balancer) Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-ALB-SG"
  description = "Allows HTTP/S traffic from the internet and sends it to ECS Fargate."
  vpc_id      = aws_vpc.app_vpc.id

  # Ingress: Allow HTTP (80) and HTTPS (443) from the Internet
  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Allow outbound connections to anywhere.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-ALB-SG"
  }
}

# -----------------------------------------------------------------------------
# Ingress Rule for Backend (ALB Referencing)
# -----------------------------------------------------------------------------
# We create the SG first, then define the ingress rule that references the ALB SG.
resource "aws_security_group_rule" "backend_ingress" {
  description              = "Allow traffic from the ALB"
  type                     = "ingress"
  from_port                = 8080 # Assuming your Spring Boot app runs on 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.alb.id # ONLY from the ALB SG
}


# -----------------------------------------------------------------------------
# OUTPUTS (Needed for Database and ECS files)
# -----------------------------------------------------------------------------
output "rds_security_group_id" {
  description = "The ID of the RDS security group."
  value       = aws_security_group.rds.id
}

output "backend_security_group_id" {
  description = "The ID of the Spring Boot Backend security group."
  value       = aws_security_group.backend.id
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group."
  value       = aws_security_group.alb.id
}