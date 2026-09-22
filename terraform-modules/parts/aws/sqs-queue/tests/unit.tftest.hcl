mock_provider "aws" {}

variables {
  required_vpc_id = "vpc-0123456789abcdef0"
  queue_name      = "sre-dead-letter-queue"
  fifo_queue      = false
}

run "verify_sqs_creation" {
  command = plan

  assert {
    condition     = aws_sqs_queue.this.name == "sre-dead-letter-queue"
    error_message = "Queue name mismatch"
  }

  assert {
    condition     = output.vpc_id == "vpc-0123456789abcdef0"
    error_message = "VPC ID output mismatch"
  }
}

run "verify_invalid_vpc_fails" {
  command = plan

  variables {
    required_vpc_id = "invalid-vpc-without-prefix"
  }

  expect_failures = [
    var.required_vpc_id
  ]
}
