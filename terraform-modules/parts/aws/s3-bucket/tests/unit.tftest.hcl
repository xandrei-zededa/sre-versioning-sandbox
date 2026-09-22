mock_provider "aws" {}

variables {
  bucket_name                = "zededa-audit-logs"
  enable_versioning          = true
  enable_intelligent_tiering = true
  custom_tags = {
    Owner       = "SRE"
    Environment = "Audit"
  }
}

run "verify_bucket_and_tiering" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "zededa-audit-logs"
    error_message = "Bucket name mismatch"
  }

  assert {
    condition     = length(aws_s3_bucket_intelligent_tiering_configuration.this) == 1
    error_message = "Intelligent Tiering should be enabled"
  }

  assert {
    condition     = output.intelligent_tiering_enabled == true
    error_message = "Output flag mismatch"
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Owner"] == "SRE"
    error_message = "Custom Owner tag was not applied"
  }
}
