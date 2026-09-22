# Playbook 04: Emergency 30-Second Rollback Protocol

## Context & Motivation
If an unexpected provider bug, regression, or service incident occurs after a production module upgrade, rollback must be deterministic and instantaneous.

---

## What NOT to Do
* ❌ DO NOT run `git revert` on the module commit in `main`.
* ❌ DO NOT rewrite Git tags (`git tag -f`).
* ❌ DO NOT attempt quick hotfixes directly in Production state.

---

## Standard 30-Second Rollback Procedure

### Step 1: Open Target Cluster Configuration
Locate the affected deployment file, e.g.:
`terragrunt/deployments/production/zedcloud-production/cluster/terragrunt.hcl`

### Step 2: Edit Tag Reference
Revert the `ref` parameter to the previously known-good semantic tag:

```hcl
terraform {
  # Change from failing version:
  # source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.3.0"

  # Revert to stable version:
  source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.2.0"
}
```

### Step 3: Apply Rollback
Execute via Atlantis in PR or via local Terragrunt CLI:
```bash
terragrunt apply -auto-approve
```

### Step 4: Verification
Verify that cluster outputs, node pools, or resources have restored to their stable baseline:
```bash
terragrunt output
```
Rollback is complete. Blast radius was contained strictly to the target deployment without touching any other cluster or shared code.
