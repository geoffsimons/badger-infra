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

resource "aws_iam_policy" "ecs_app_policy" {
  name        = "${var.app_name}-ecs-app-policy"
  description = "Minimal policy for the application to run inside the container."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ADD SPECIFIC APPLICATION PERMISSIONS HERE
      # Example: If using Secrets Manager for DB password:
      # {
      #   Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
      #   Effect   = "Allow",
      #   Resource = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:MY_DB_SECRET-*"
      # },
      # For now, we have a dummy and safe placeholder
      { # TODO Remove this when we are ready to make the real policy.
        Action   = "s3:ListAllMyBuckets",
        Effect   = "Deny",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_app_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_app_policy.arn
}
