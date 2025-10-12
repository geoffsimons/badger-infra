variable "app_name" {
  description = "A unique prefix for all infrastructure resources."
  type        = string
  default     = "badger"
}

variable "environment" {
  description = "The environment to operate on."
  type        = string
  default     = "dev"
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

variable "jwt_secret" {
  description = "Secret used to sign JWTs."
  type        = string
  sensitive   = true
}

variable "jwt_ttl" {
  description = "Time to Live for JWT in ms."
  type        = string
  # Default is set to 7 days
  default     = "604800000"
}

variable "google_client_id" {
  description = "OAuth Client Id from Google."
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "OAuth Client Secret for Google."
  type        = string
  sensitive   = true
}

variable "oauth2_redirect_uri_success" {
  description = "Redirect URL on Oauth Success."
  type        = string
  default     = "http://localhost:3000/oauth2/redirect"
}
