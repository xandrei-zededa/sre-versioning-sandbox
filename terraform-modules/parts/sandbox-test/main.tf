variable "environment" {
  type        = string
  description = "Target deployment environment name"
  default     = "sandbox"

  validation {
    condition     = contains(["sandbox", "dev", "prod"], var.environment)
    error_message = "Environment must be one of: sandbox, dev, prod."
  }
}

variable "component_name" {
  type        = string
  description = "Name of the component"
  default     = "poc-runner"
}

locals {
  full_identifier = "${var.environment}-${var.component_name}"
  is_production   = var.environment == "prod"
}

output "identifier" {
  description = "Computed identifier"
  value       = local.full_identifier
}

output "is_production" {
  description = "Flag indicating production deployment"
  value       = local.is_production
}
