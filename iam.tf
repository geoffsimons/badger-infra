# 1. Define the Policy for your Application's Deployment
#    This policy grants the MINIMUM required permissions for your full-stack deployment.
resource "aws_iam_policy" "app_deployment_policy" {
  name        = "${var.app_name}-Terraform-Deployment-Policy"
  description = "Permissions for Terraform to manage Badger infrastructure (VPC, RDS, ECS, S3, CloudFront)."

  # NOTE: This is an example. In production, you would restrict 'Resource' to specific ARNs.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "iam:List*",
          "iam:Get*",
          "iam:AttachGroupPolicy",
          "iam:DetachGroupPolicy",
          "iam:TagUser",
          "iam:UntagUser"
        ],
        "Resource": "*"
      },
      {
        # Permissions for Networking (VPC)
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        # Permissions for Database (RDS)
        Effect   = "Allow"
        Action   = ["rds:*"]
        Resource = "*"
      },
      {
        # Permissions for Container Services (ECS/Fargate, ECR)
        Effect   = "Allow"
        Action   = ["ecs:*", "ecr:*", "iam:CreateRole", "iam:PutRolePolicy", "iam:DeleteRole", "iam:DeleteRolePolicy"]
        Resource = "*"
      },
      {
        # Permissions for Static Hosting (S3, CloudFront)
        Effect   = "Allow"
        Action   = ["s3:*", "cloudfront:*"]
        Resource = "*"
      },
      {
        # REQUIRED: Allows the Terraform execution role to "pass" roles to AWS services (e.g., Fargate Task Role)
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*" # Restrict this to only roles created for the application (e.g., ECS task role)
      }
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
