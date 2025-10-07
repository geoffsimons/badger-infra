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
