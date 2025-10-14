# -----------------------------------------------------------------------------
# ECR Repository
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.app_name}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# -----------------------------------------------------------------------------
# ECR Lifecycle Policy
# This policy keeps the latest 5 images and deletes all others after 14 days.
# This prevents costs from accumulating due to old, unused images.
# -----------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "app_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire images older than 14 days, excluding the last 5",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 14
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "Keep the latest 5 images",
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = 5
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_url" {
  description = "The URL of the ECR Repository for Docker pushes."
  value       = aws_ecr_repository.app_repo.repository_url
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"

  # Optional: Configure CloudWatch Container Insights for monitoring
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# -----------------------------------------------------------------------------
# ECS Task Execution Role (For the ECS Agent)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_exec_role" {
  name = "${var.app_name}-ecs-exec-role"

  # Trust policy allowing the ECS service principal to assume the role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AWS-managed policy for Task Execution (includes ECR access, CloudWatch Logs access)
resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS Task Execution Role."
  value       = aws_iam_role.ecs_exec_role.arn
}

# -----------------------------------------------------------------------------
# ECS Task Role (For the Application Code)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-ecs-task-role"

  # Trust policy allowing the ECS service principal to assume the role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS Task Role."
  value       = aws_iam_role.ecs_task_role.arn
}

# TODO: Uncomment these for ECS to use S3
#    We might also need to setup some other stuff in a s3.tf config.
# resource "aws_iam_policy" "ecs_app_policy" {
#   name        = "${var.app_name}-ecs-app-policy"
#   description = "Permissions for the application code (S3, DynamoDB, etc.)."
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action   = ["s3:GetObject", "s3:PutObject"],
#         Effect   = "Allow",
#         Resource = "arn:aws:s3:::${var.app_name}-data/*" # SCOPE TO YOUR BUCKET
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_app_attach" {
#   role       = aws_iam_role.ecs_task_role.name
#   policy_arn = aws_iam_policy.ecs_app_policy.arn
# }

# -----------------------------------------------------------------------------
# CloudWatch Log Groups (Prerequisite for Task Definitions)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "backend_log_group" {
  name              = "/ecs/${var.app_name}-backend" # Use a distinct name for the backend
  retention_in_days = 30
  tags = {
    Name = "${var.app_name}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "frontend_log_group" {
  name              = "/ecs/${var.app_name}-frontend" # Use a distinct name for the frontend
  retention_in_days = 7 # Example: Frontend might need shorter retention
  tags = {
    Name = "${var.app_name}-frontend-logs"
  }
}

# -----------------------------------------------------------------------------
# ECS Task Definition (The blueprint for your container)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.app_name}-task"
  cpu                      = 1024       # Example: 1 vCPU
  memory                   = 2048       # Example: 2 GB
  network_mode             = "awsvpc"   # Required for Fargate
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-container",
      image     = "${aws_ecr_repository.app_repo.repository_url}:badger-backend-20251014102757", # Reference ECR URL
      cpu       = 1024,
      memory    = 2048,
      essential = true,
      portMappings = [
        {
          containerPort = 8080, # Spring Boot default port
          hostPort      = 8080
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend_log_group.name,
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "ecs"
        }
      },
      environment = [
        # Tells Spring Boot to use X-Forwarded-* headers
        { name = "SERVER_FORWARD_HEADERS_STRATEGY", value = "FRAMEWORK" },
        # Explicitly tells Tomcat/Jetty to use this header for protocol
        { name = "SERVER_TOMCAT_REMOTEIP_PROTOCOL_HEADER", value = "x-forwarded-proto" }
      ],
      secrets = [
        {
          # Environment Variable name your Spring Boot app expects
          name      = "SPRING_DATASOURCE_URL",
          # Reference the ARN, then use the :jsonKey: syntax to pull 'DB_URL' from the JSON
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_URL::"
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME",
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_USERNAME::"
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD",
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_PASSWORD::"
        },
        { name: "JWT_SECRET", valueFrom: "${aws_secretsmanager_secret.app_config.arn}:JWT_SECRET::" },
        { name: "JWT_TTL", valueFrom: "${aws_secretsmanager_secret.app_config.arn}:JWT_TTL::" },
        { name: "SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_GOOGLE_CLIENT_ID", valueFrom: "${aws_secretsmanager_secret.app_config.arn}:GOOGLE_CLIENT_ID::" },
        { name: "SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_GOOGLE_CLIENT_SECRET", valueFrom: "${aws_secretsmanager_secret.app_config.arn}:GOOGLE_CLIENT_SECRET::" },
        { name: "APP_OAUTH2_REDIRECT_URI_SUCCESS", valueFrom: "${aws_secretsmanager_secret.app_config.arn}:APP_OAUTH2_REDIRECT_URI_SUCCESS::" }
      ]
    }
  ])
}

# -----------------------------------------------------------------------------
# ECS Service (Keeps the Task Definition running and connects it to the ALB)
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "backend_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 2 # Start with 2 tasks for high availability
  launch_type     = "FARGATE"

  # Connect the service to the ALB Target Group
  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "${var.app_name}-container" # Name from Task Definition
    container_port   = 8080
  }

  network_configuration {
    subnets          = aws_subnet.private.*.id # Fargate tasks must run in private subnets
    security_groups  = [aws_security_group.backend.id] # The Backend SG
    assign_public_ip = false # Tasks in private subnets should NOT get public IPs
  }

  # Prevents Terraform from trying to manage the service's desired count
  # if you use ECS Service Auto Scaling or manual scaling
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name = "${var.app_name}-service"
  }
}

# -----------------------------------------------------------------------------
# ECS Task Definition (Frontend)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "${var.app_name}-frontend-task"
  cpu                      = 512        # Smaller CPU/Memory for a static frontend
  memory                   = 1024
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-frontend-container",
      image     = "${aws_ecr_repository.app_repo.repository_url}:badger-frontend-20251011191932",
      cpu       = 512,
      memory    = 1024,
      essential = true,
      portMappings = [
        {
          containerPort = 80, # Nginx/Frontend container default port
          hostPort      = 80
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend_log_group.name,
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "ecs"
        }
      },
      environment = [],
      # React apps often need environment variables for API URL, but no secrets here
      secrets     = []
    }
  ])
}

# -----------------------------------------------------------------------------
# ECS Service (Frontend - Connects to the new Target Group)
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "frontend_service" {
  name            = "${var.app_name}-frontend-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  # Connect the service to the NEW Frontend Target Group (app_frontend_tg below)
  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "${var.app_name}-frontend-container"
    container_port   = 80
  }

  network_configuration {
    subnets          = aws_subnet.private.*.id
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  # Prevents Terraform from trying to manage the service's desired count
  lifecycle {
    ignore_changes = [desired_count]
  }
}
