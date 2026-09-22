terraform {
  # Production-кластер зафиксирован на стабильной версии v1.0.0
  source = "git::https://github.com/xandrei-zededa/sre-versioning-sandbox.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
}

inputs = {
  cluster_name    = "prod-zedcloud"
  cluster_version = "1.30"
  enable_waf      = false
}
