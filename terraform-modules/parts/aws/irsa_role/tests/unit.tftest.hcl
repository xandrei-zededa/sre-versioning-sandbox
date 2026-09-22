mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRoleWithWebIdentity\"}]}"
    }
  }
}

variables {
  role_name         = "irsa-telemetry-role"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/TEST"
  oidc_provider_url = "oidc.eks.us-west-2.amazonaws.com/id/TEST"
  subjects          = ["system:serviceaccount:monitoring:signoz-otel"]
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

run "verify_role_and_attachments" {
  command = plan

  assert {
    condition     = aws_iam_role.this.name == "irsa-telemetry-role"
    error_message = "Role name mismatch"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 1
    error_message = "Expected exactly 1 policy attachment"
  }
}
