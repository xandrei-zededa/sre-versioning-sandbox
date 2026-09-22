# Playbook 01: Creating a New Module from Scratch

## Context & Motivation
When introducing a new infrastructure domain (e.g., Kafka, Vault, or Cloudflare DNS), you must follow the semantic packaging pattern. This ensures the module is testable in memory and versioned automatically without impacting existing fleet deployments.

---

## Step-by-Step Procedure

### 1. Scaffold Module Directory
Create a dedicated subfolder under `terraform-modules/parts/<domain>/<module_name>`:
```bash
mkdir -p terraform-modules/parts/aws/sqs-queue/tests
```

### 2. Define Module Code (`main.tf`, `variables.tf`, `outputs.tf`)
Write idiomatic HCL. Always enforce variable validation rules:
```hcl
# terraform-modules/parts/aws/sqs-queue/main.tf
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
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
  description = "Boolean designating a FIFO queue"
}

resource "aws_sqs_queue" "this" {
  name       = var.queue_name
  fifo_queue = var.fifo_queue
}

output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.this.arn
}
```

### 3. Implement Mock Unit Test (`tests/unit.tftest.hcl`)
Write assertions using `mock_provider "aws" {}`. **Zero cloud tokens required**:
```hcl
mock_provider "aws" {}

variables {
  queue_name = "sre-alert-events"
  fifo_queue = false
}

run "verify_queue_creation" {
  command = plan

  assert {
    condition     = aws_sqs_queue.this.name == "sre-alert-events"
    error_message = "SQS queue name mismatch"
  }

  assert {
    condition     = aws_sqs_queue.this.fifo_queue == false
    error_message = "Expected standard queue"
  }
}

run "verify_invalid_name_fails_validation" {
  command = plan

  variables {
    queue_name = "invalid/name/with/slashes"
  }

  expect_failures = [
    var.queue_name
  ]
}
```

### 4. Execute Local Self-Verification Gates
Run three standard checks before committing:
```bash
# 1. Format check
tofu fmt -check terraform-modules/parts/aws/sqs-queue

# 2. Security scan
trivy config --severity HIGH,CRITICAL terraform-modules/parts/aws/sqs-queue

# 3. Unit test
(cd terraform-modules/parts/aws/sqs-queue && tofu init -backend=false && tofu test)
```

### 5. Register in Release Please Manifests
Add the new package path to `release-please-config.json`:
```json
"terraform-modules/parts/aws/sqs-queue": {
  "release-type": "terraform-module",
  "package-name": "modules/sqs-queue",
  "changelog-path": "CHANGELOG.md"
}
```
Set initial tracking version in `.release-please-manifest.json`:
```json
"terraform-modules/parts/aws/sqs-queue": "1.0.0"
```

### 6. Commit & Open Pull Request
```bash
git checkout -b feat/add-sqs-module
git add terraform-modules/parts/aws/sqs-queue/ release-please-config.json .release-please-manifest.json
git commit -m "feat(sqs-queue): initial implementation with zero-cloud unit tests"
git push -u origin feat/add-sqs-module
```
Release Please will generate tag `modules/sqs-queue-v1.0.0` upon merge.
