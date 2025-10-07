## Execution Steps (The One-Time Run)
1. Save the File: Save the code above as bootstrap.tf in your main Terraform directory.

2. Initialize: Initialize Terraform in your project directory.
```bash
# This command reads the new .tf files and sets up the backend
export AWS_PROFILE=badger-bootstrap # Use the highly-privileged profile
terraform init
```

3. Apply: Run the apply command to create the IAM group, policy, and user.
```bash
# This will create your IAM resources
export AWS_PROFILE=badger-bootstrap # STILL using the highly-privileged profile
terraform apply --target aws_iam_group.terraform_admins --target aws_iam_policy.app_deployment_policy -auto-approve
```

4. Apply part 2: Create admin user
```bash
export AWS_PROFILE=badger-bootstrap
terraform apply -auto-approve
```

## Next Steps: Transition to Least Privilege
After a successful run of the bootstrap.tf file:

1. Generate Keys: Generate new Access Keys for the `badger-admin`.

2. Configure Admin Profile: Run aws configure and set up your [badger-admin] profile using the new, restricted user's keys.
```bash
aws configure --profile badger-admin
```

3. Security Cleanup: Delete the keys for the highly-privileged `badger-bootstrap` user.

From now on, all your further Terraform files (like `network.tf`, `database.tf`, etc.) can be applied using your `[badger-admin]` profile, which adheres to the principle of least privilege.
