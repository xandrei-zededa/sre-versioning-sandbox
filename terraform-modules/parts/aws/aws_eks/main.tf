terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes control plane version"
  default     = "1.30"
}

variable "enable_waf" {
  type        = bool
  description = "Enable AWS WAF association"
  default     = false
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = "arn:aws:iam::123456789012:role/eks-cluster-role"

  vpc_config {
    subnet_ids = ["subnet-11111111", "subnet-22222222"]
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = "arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/eks-alb/123"
  web_acl_arn  = "arn:aws:wafv2:us-west-2:123456789012:regional/webacl/security-rules/123"
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

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
