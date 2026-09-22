mock_provider "aws" {}

variables {
  cluster_name = "madmax-cluster"
  enable_waf   = true
}

run "verify_eks_and_waf_count" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.name == "madmax-cluster"
    error_message = "Unexpected cluster name"
  }

  assert {
    condition     = length(aws_wafv2_web_acl_association.alb) == 1
    error_message = "WAF association should be enabled when enable_waf is true"
  }
}
