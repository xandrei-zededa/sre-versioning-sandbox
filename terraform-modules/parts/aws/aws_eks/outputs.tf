output "cluster_version" {
  value = aws_eks_cluster.this.version
}

output "waf_enabled" {
  value = var.enable_waf
}

output "karpenter_node_role" {
  description = "New Karpenter node IAM role introduced in this release"
  value       = "arn:aws:iam::123456789012:role/karpenter-node-role"
}

output "vpc_cni_addon_enabled" {
  description = "Multi-package feature flag"
  value       = true
}
