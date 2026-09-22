terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# BREAKING CHANGE: required_vpc_id is now mandatory with no default
variable "required_vpc_id" {
  type        = string
  description = "Mandatory VPC identifier for isolation"

  validation {
    condition     = startswith(var.required_vpc_id, "vpc-")
    error_message = "VPC ID must start with vpc- prefix."
  }
}

variable "queue_name" {
  type        = string
  description = "Name of the standard SQS queue"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.queue_name))
    error_message = "Queue name contains invalid characters."
  }
}

variable "fifo_queue" {
  type        = bool
  default     = false
  description = "Designate as FIFO queue"
}

resource "aws_sqs_queue" "this" {
  name       = var.queue_name
  fifo_queue = var.fifo_queue
}

output "queue_arn" {
  description = "ARN of SQS queue"
  value       = aws_sqs_queue.this.arn
}

output "queue_id" {
  description = "ID of SQS queue"
  value       = aws_sqs_queue.this.id
}

output "vpc_id" {
  description = "Attached mandatory VPC ID"
  value       = var.required_vpc_id
}
