provider "aws" {
  region  = "us-west-2"
  # The bootstrap user a temporary user with permissions to create our admin user,
  # which we will use for all operations once we have completed the required targets.
  # profile = "badger-bootstrap"
  profile = "badger-admin"
}
