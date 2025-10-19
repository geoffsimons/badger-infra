# -----------------------------------------------------------------------------
# ALB Target Group for the Frontend
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "frontend_tg" {
  name        = "${var.app_name}-frontend-tg"
  port        = 80 # The port your Nginx/Frontend container exposes
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id

  target_type = "ip"

  health_check {
    path = "/" # React frontends usually serve static content at /
    protocol = "HTTP"
    matcher = "200"
  }

  tags = {
    Name = "${var.app_name}-frontend-tg"
  }
}

# -----------------------------------------------------------------------------
# Target group for the backend
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "backend_tg" {
  name        = "${var.app_name}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id
  target_type = "ip"

  stickiness {
    type    = "app_cookie" # For session-based affinity (most common for OAuth)
    enabled = true
    # The name of the cookie the load balancer uses to track the session.
    # The value is arbitrary, but required if type is not 'lb_cookie'.
    cookie_duration = 86400 # 24 hours (in seconds)
    cookie_name     = "JSESSIONID"
  }

  health_check {
    path     = "/actuator/health" # Your Spring Boot Actuator endpoint
    protocol = "HTTP"
    matcher  = "200"
  }

  tags = {
    Name = "${var.app_name}-backend-tg"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer (The traffic entry point)
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
# ALB Listener (Routes traffic from 443 with Host-Based Routing)
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.app_cert.arn

  # Set the default action to forward traffic to the Frontend.
  # All unmatched traffic will hit this rule.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# -----------------------------------------------------------------------------
# Listener Rule for the Backend
# -----------------------------------------------------------------------------
resource "aws_lb_listener_rule" "backend_api_rule" {
  listener_arn = aws_lb_listener.app_listener.arn
  priority     = 10 # Lower number means higher priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn # The Spring Boot TG
  }

  condition {
    host_header {
      values = ["api.${var.app_domain}"]
    }
  }
}
