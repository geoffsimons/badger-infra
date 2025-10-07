variable "app_name" {
  description = "A unique prefix for all infrastructure resources."
  type        = string
  default     = "badger"
}

variable "region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (e.g., for Load Balancers)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (e.g., for RDS, ECS)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "db_name" {
  description = "The database name for the PostgreSQL instance."
  type        = string
  default     = "badger_db"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "badger_db_admin"
}

variable "db_password" {
  description = "Master password for the RDS instance. USE A SECURE VALUE!"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "The size/class of the RDS instance."
  type        = string
  default     = "db.t3.micro"
}
