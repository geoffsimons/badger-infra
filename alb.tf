# -----------------------------------------------------------------------------
# 1. ALB Target Group (The destination for traffic)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.app_name}-tg"
  port        = 8080 # The port your Spring Boot container exposes (matches the ECS Task Def)
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id

  target_type = "ip"

  health_check {
    path = "/actuator/health" # Assuming you have a Spring Boot Actuator health endpoint
    protocol = "HTTP"
    matcher = "200"
  }

  tags = {
    Name = "${var.app_name}-tg"
  }
}

# -----------------------------------------------------------------------------
# 2. Application Load Balancer (The traffic entry point)
# -----------------------------------------------------------------------------
resource "aws_lb" "app_alb" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id] # The ALB SG created earlier
  subnets            = aws_subnet.public.*.id # ALB must be in public subnets

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# -----------------------------------------------------------------------------
# 3. ALB Listener (Routes traffic from 443 to the Target Group)
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  # You need to substitute your actual ACM Certificate ARN here
  certificate_arn   = aws_acm_certificate.app_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

output "app_alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.app_alb.dns_name
}
