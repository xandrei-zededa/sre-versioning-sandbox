mock_provider "aws" {}

variables {
  queue_name = "sre-dead-letter-queue"
  fifo_queue = false
}

run "verify_sqs_creation" {
  command = plan

  assert {
    condition     = aws_sqs_queue.this.name == "sre-dead-letter-queue"
    error_message = "Queue name mismatch"
  }

  assert {
    condition     = aws_sqs_queue.this.fifo_queue == false
    error_message = "Expected standard SQS queue"
  }
}

run "verify_invalid_name_fails" {
  command = plan

  variables {
    queue_name = "invalid/queue/name"
  }

  expect_failures = [
    var.queue_name
  ]
}
