terraform {
  # Dev-кластер madmax подключен к модулю EKS
  source = "git::https://github.com/xandrei-zededa/sre-versioning-sandbox.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
}

inputs = {
  cluster_name    = "dev-madmax"
  cluster_version = "1.30"
  enable_waf      = true
}
