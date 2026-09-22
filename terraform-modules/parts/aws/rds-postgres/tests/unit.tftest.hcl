mock_provider "aws" {}

variables {
  identifier = "central-audit-db"
}

run "verify_rds_defaults" {
  command = plan

  assert {
    condition     = aws_db_instance.this.identifier == "central-audit-db"
    error_message = "DB identifier mismatch"
  }

  assert {
    condition     = aws_db_instance.this.engine == "postgres"
    error_message = "Expected engine postgres"
  }
}
