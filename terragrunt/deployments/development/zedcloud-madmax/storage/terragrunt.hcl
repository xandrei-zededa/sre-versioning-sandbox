generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region                      = "us-west-2"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  access_key                  = "mock_key"
  secret_key                  = "mock_secret"
}
EOF
}

terraform {
  source = "git::https://github.com/xandrei-zededa/sre-versioning-sandbox.git//terraform-modules/parts/aws/s3-bucket?ref=modules/s3-bucket-v1.2.0"
}

inputs = {
  bucket_name                = "zedcloud-madmax-audit-storage"
  enable_versioning          = true
  enable_intelligent_tiering = true
}
