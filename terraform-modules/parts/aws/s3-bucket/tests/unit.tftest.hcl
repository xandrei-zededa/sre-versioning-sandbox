mock_provider "aws" {}

variables {
  bucket_name       = "zededa-audit-logs"
  enable_versioning = true
}

run "verify_bucket_and_versioning" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "zededa-audit-logs"
    error_message = "Bucket name mismatch"
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled"
  }
}
