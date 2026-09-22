run "verify_default_values" {
  command = plan

  assert {
    condition     = output.identifier == "sandbox-poc-runner"
    error_message = "Unexpected default identifier output"
  }

  assert {
    condition     = output.is_production == false
    error_message = "Sandbox environment should not be detected as production"
  }
}

run "verify_prod_flag" {
  command = plan

  variables {
    environment    = "prod"
    component_name = "api-gateway"
  }

  assert {
    condition     = output.identifier == "prod-api-gateway"
    error_message = "Unexpected production identifier"
  }

  assert {
    condition     = output.is_production == true
    error_message = "Production environment must have is_production == true"
  }
}

run "verify_invalid_env_fails" {
  command = plan

  variables {
    environment = "invalid-env"
  }

  expect_failures = [
    var.environment
  ]
}
