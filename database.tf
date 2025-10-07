# -----------------------------------------------------------------------------
# 1. DB Subnet Group (Required to place RDS in a VPC)
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.app_name}-subnet-group"
  description = "Subnet group for the RDS database."

  # Reference the Private Subnets created in network.tf
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${var.app_name}-DB-Subnet-Group"
  }
}

# -----------------------------------------------------------------------------
# 2. DB Parameter Group (Optional but Recommended for custom config)
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "postgres_params" {
  name   = "${var.app_name}-postgres-params"
  family = "postgres17" # Check AWS for the latest supported version

  # Example parameter change (adjust as needed)
  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = {
    Name = "${var.app_name}-Postgres-Params"
  }
}

# -----------------------------------------------------------------------------
# 3. PostgreSQL RDS Instance
# -----------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier           = "${var.app_name}-postgres-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "17.4"
  instance_class       = var.db_instance_class
  username             = var.db_username
  password             = var.db_password
  db_name              = var.db_name
  multi_az             = true                  # Enable Multi-AZ for high availability
  skip_final_snapshot  = true                  # CHANGE THIS TO FALSE IN PRODUCTION!
  publicly_accessible  = false                 # CRITICAL: Keep the DB in private subnets
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  parameter_group_name = aws_db_parameter_group.postgres_params.name

  # Reference the RDS Security Group created in security.tf
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = {
    Name = "${var.app_name}-PostgreSQL-Instance"
  }
}


# -----------------------------------------------------------------------------
# OUTPUTS (Critical for the Spring Boot Backend)
# -----------------------------------------------------------------------------
output "rds_endpoint" {
  description = "The connection endpoint for the RDS PostgreSQL database."
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "The port for the RDS PostgreSQL database."
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "The name of the database."
  value       = aws_db_instance.postgres.db_name
}
