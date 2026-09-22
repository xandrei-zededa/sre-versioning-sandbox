terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "enable_versioning" {
  type        = bool
  description = "Enable versioning for S3 bucket"
  default     = true
}

variable "enable_intelligent_tiering" {
  type        = bool
  description = "Enable S3 Intelligent-Tiering archive configurations"
  default     = false
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  count  = var.enable_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "EntireBucketIntelligentTiering"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

output "bucket_id" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "intelligent_tiering_enabled" {
  description = "Whether Intelligent Tiering archive is active"
  value       = var.enable_intelligent_tiering
}
