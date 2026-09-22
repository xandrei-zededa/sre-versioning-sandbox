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
  # Dev cluster madmax updated to v1.1.0 with Karpenter
  source = "git::https://github.com/xandrei-zededa/sre-versioning-sandbox.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.1.0"
}

inputs = {
  cluster_name    = "dev-madmax"
  cluster_version = "1.30"
  enable_waf      = true
}
