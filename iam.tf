# 1. Define the Policy for your Application's Deployment
#    This policy grants the MINIMUM required permissions for your full-stack deployment.
resource "aws_iam_policy" "app_deployment_policy" {
  name        = "${var.app_name}-Terraform-Deployment-Policy"
  description = "Permissions for Terraform to manage Badger infrastructure (VPC, RDS, ECS, S3, CloudFront)."

  # NOTE: This is an example. In production, you would restrict 'Resource' to specific ARNs.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          // ESSENTIAL READ ACTIONS
          "ec2:Describe*",     // Fixes EC2 errors (VPC, AZs, Subnets)
          "rds:Describe*",     // Fixes RDS errors (Parameter Groups, Subnets)
          "iam:Get*",          // Fixes IAM errors (Policy, Group, User)
          "iam:List*",         // Fixes IAM errors

          // FULL MANAGEMENT ACTIONS (for creating/updating resources)
          "ec2:*",
          "rds:*",
          "s3:*",
          "ecs:*",
          "ecr:*",
          "acm:*",

          // FULL IAM MANAGEMENT ACTIONS
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:DeletePolicyVersion",
          "iam:AttachGroupPolicy",
          "iam:DetachGroupPolicy",
          "iam:UpdateGroup",
          "iam:TagUser",
          "iam:UntagUser",
          "iam:PassRole",
          "iam:CreateServiceLinkedRole",
          "iam:AttachRolePolicy",

          # Elastic Load Balancing (ALB/Target Group/Listener)
          "elasticloadbalancing:*" ,

          # CloudWatch Logs (For creating and managing log groups)
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource",

          # Secrets Manager (For creating/managing the secret itself)
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue"
        ],
        "Resource": "*"
      }
      // You may have other statements, but this single, broad statement
      // is often easiest for a single application stack.
    ]
  })
}

# 2. Define the IAM Group for your deployment team
resource "aws_iam_group" "terraform_admins" {
  name = "${var.app_name}-Terraform-Admins"
}

# 3. Attach the restricted deployment policy to the new group
resource "aws_iam_group_policy_attachment" "deployment_attach" {
  group      = aws_iam_group.terraform_admins.name
  policy_arn = aws_iam_policy.app_deployment_policy.arn
}

# 4. Optional: Create an IAM User (for your permanent, non-bootstrap identity)
#    You would generate keys for this user and use them for all future 'terraform apply' runs.
resource "aws_iam_user" "permanent_admin_user" {
  name = "badger-admin"
  # Path is optional but can help organize
  path = "/developers/"
}

# 5. Optional: Add the permanent user to the newly created group
resource "aws_iam_user_group_membership" "admin_membership" {
  user   = aws_iam_user.permanent_admin_user.name
  groups = [aws_iam_group.terraform_admins.name]
}

# -------------------------------
# SECRETS Access for ECS
# -------------------------------
resource "aws_iam_policy" "ecs_exec_secrets_policy" {
  name        = "${var.app_name}-exec-secrets-policy"
  description = "Allows ECS agent to retrieve all necessary secrets for container launch."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Effect   = "Allow",
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
          aws_secretsmanager_secret.app_config.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_secrets_attach" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = aws_iam_policy.ecs_exec_secrets_policy.arn
}

resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
  description      = "Allows Amazon ECS to access your resources."
}
