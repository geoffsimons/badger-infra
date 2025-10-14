resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.app_name}/${var.environment}/database-v1"
  description = "RDS credentials for the ${var.environment} environment."
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  # Store the full configuration as a single JSON object
  secret_string = jsonencode({
    DB_URL      = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/${var.db_name}",
    DB_USERNAME = var.db_username,
    DB_PASSWORD = var.db_password
  })
}

output "db_secret_arn" {
  description = "The ARN of the database credentials secret."
  value       = aws_secretsmanager_secret.db_credentials.arn
  sensitive   = true
}

resource "aws_secretsmanager_secret" "app_config" {
  name        = "${var.app_name}/${var.environment}/application-config"
  description = "Application configuration secrets for OAuth and JWT."
}

resource "aws_secretsmanager_secret_version" "app_config_version" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    JWT_SECRET                     = var.jwt_secret,
    JWT_TTL                        = var.jwt_ttl,
    GOOGLE_CLIENT_ID               = var.google_client_id,
    GOOGLE_CLIENT_SECRET           = var.google_client_secret,
    APP_OAUTH2_REDIRECT_URI_SUCCESS = var.oauth2_redirect_uri_success
  })
}
