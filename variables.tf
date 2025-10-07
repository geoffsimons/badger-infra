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
