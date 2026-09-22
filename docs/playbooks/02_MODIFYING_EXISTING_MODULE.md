# Playbook 02: Modifying an Existing Module Without Breaking Production

## Context & Motivation
When updating an existing module (e.g., adding Karpenter support or updating IAM roles), you must verify backward compatibility locally and guarantee that production clusters remain pinned to their established versions.

---

## Step-by-Step Procedure

### 1. Identify Target Module & Current Release
Check the current tag in `.release-please-manifest.json` (e.g., `aws_eks` is at `1.2.0`).

### 2. Implement HCL Changes
Add non-breaking arguments with defaults:
```hcl
variable "enable_karpenter" {
  type        = bool
  default     = false
  description = "Enable Karpenter autoscaling controller"
}
```

### 3. Update Existing Unit Tests
Add an assertion in `tests/unit.tftest.hcl`:
```hcl
run "verify_karpenter_flag" {
  command = plan

  variables {
    cluster_name     = "test-cluster"
    enable_karpenter = true
  }

  assert {
    condition     = output.karpenter_enabled == true
    error_message = "Karpenter output mismatch"
  }
}
```

### 4. Run Live Local Preview (`TG_SOURCE` Override)
To verify how your unreleased changes look in a real cluster without publishing a tag:
```bash
cd terragrunt/deployments/development/zedcloud-madmax/cluster
TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
```
Inspect the diff. Notice that no remote Git tag is modified.

### 5. Commit Using Conventional Commits
* **If adding a feature:**
  ```bash
  git commit -m "feat(aws-eks): add karpenter controller integration"
  ```
  *(Triggers MINOR bump: v1.2.0 -> v1.3.0)*
* **If fixing a bug:**
  ```bash
  git commit -m "fix(aws-eks): resolve invalid security group rule"
  ```
  *(Triggers PATCH bump: v1.2.0 -> v1.2.1)*

### 6. Verify Production Immunity
After merge into `main`:
1. Release Please publishes `modules/aws-eks-v1.3.0`.
2. Review `terragrunt/deployments/production/zedcloud-production/cluster/terragrunt.hcl`.
3. Confirm it still points to `?ref=modules/aws-eks-v1.0.0` or `v1.2.0`.
4. Production does not experience any changes until explicitly promoted.
