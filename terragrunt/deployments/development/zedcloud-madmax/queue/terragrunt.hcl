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
  # Кластер madmax использует SQS очередь предыдущей версии v2.0.0
  source = "git::https://github.com/xandrei-zededa/sre-versioning-sandbox.git//terraform-modules/parts/aws/sqs-queue?ref=modules/sqs-queue-v2.0.0"
}

inputs = {
  required_vpc_id = "vpc-0123456789abcdef0"
  queue_name      = "madmax-audit-queue"
  fifo_queue      = false
}
