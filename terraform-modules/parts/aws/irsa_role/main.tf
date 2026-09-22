terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role to create."

  validation {
    condition     = length(var.role_name) <= 64 && can(regex("^[A-Za-z0-9+=,.@_-]+$", var.role_name))
    error_message = "IAM role names are at most 64 characters and limited to [A-Za-z0-9+=,.@_-]."
  }
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the cluster IAM OIDC provider."
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS OIDC issuer as host and path with NO scheme."

  validation {
    condition     = !startswith(var.oidc_provider_url, "https://") && !startswith(var.oidc_provider_url, "http://")
    error_message = "oidc_provider_url must not include a scheme."
  }
}

variable "subjects" {
  type        = list(string)
  description = "Service accounts allowed to assume the role."
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "List of IAM managed policy ARNs to attach."
  default     = []
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "EksIrsa"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = var.subjects
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "managed" {
  count      = length(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = var.managed_policy_arns[count.index]
}

output "role_arn" {
  description = "ARN of IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of IAM role"
  value       = aws_iam_role.this.name
}
