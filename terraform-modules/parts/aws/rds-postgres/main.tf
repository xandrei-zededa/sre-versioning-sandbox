terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "identifier" {
  type        = string
  description = "Database identifier"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB"
  default     = 50
}

variable "instance_class" {
  type        = string
  description = "Instance type"
  default     = "db.t4g.medium"
}

resource "aws_db_instance" "this" {
  identifier        = var.identifier
  allocated_storage = var.allocated_storage
  engine            = "postgres"
  engine_version    = "16.1"
  instance_class    = var.instance_class
  skip_final_snapshot = true
}

output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}
