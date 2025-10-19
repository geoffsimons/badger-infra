# Define the ACM Certificate
resource "aws_acm_certificate" "app_cert" {
  domain_name               = var.app_domain
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.app_domain}"]

  tags = {
    Name = "${var.app_name}-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Store the ARN as an output for variables.tf
output "acm_certificate_arn_output" {
  description = "The ARN of the ACM certificate."
  value       = aws_acm_certificate.app_cert.arn
}
