# LLM & AI Agent Operational Guidelines for `sre` & Terraform Monorepos

This document establishes the precise protocols, commands, and self-verification loops for LLMs and AI CLI agents (such as `opencode`, Claude Code, Cursor, Copilot Workspace) working in this repository.

---

## 1. Core Architectural Mental Model

1. **Monorepo Versioning:** Modules in `terraform-modules/parts/` are **semantically versioned packages**, not raw shared files.
2. **Blast Radius Rule:** Modifying code inside `terraform-modules/` **MUST NOT** immediately alter any deployment state. Deployments in `terragrunt/deployments/` pin immutable Git tags (e.g., `?ref=modules/aws-eks-v1.1.0`).
3. **Zero-Cloud Verification:** Never require live AWS/cloud tokens or internet connectivity to verify HCL changes. Always use OpenTofu's native `mock_provider`.

---

## 2. Step-by-Step: How to Implement a Change

When requested to add a feature, refactor, or fix an issue in a Terraform module, execute this sequence:

### Step 1: Make Idiomatic HCL Edits
* Locate target module in `terraform-modules/parts/<domain>/<module_name>/`.
* Adhere strictly to existing variable typing, validation blocks, and tags.
* Ensure output declarations include helpful descriptions.

### Step 2: Update or Add Mock Unit Tests (`.tftest.hcl`)
Every module contains a `tests/unit.tftest.hcl`. When adding a new variable or output:
1. Ensure the `mock_provider "aws" {}` block covers any data sources required by OpenTofu.
2. Add a `run` block in mode `command = plan` asserting your new logic.

Example test block:
```hcl
run "verify_new_feature" {
  command = plan

  variables {
    enable_custom_feature = true
  }

  assert {
    condition     = output.feature_status == "enabled"
    error_message = "Feature status output mismatch"
  }
}
```

---

## 3. How to Verify Work Locally (Self-Verification Loop)

Execute these three verification gates locally before proposing commits or changes:

### Gate 1: Code Formatting
```bash
tofu fmt -check terraform-modules/parts/<path_to_module>
```
*If unformatted, run `tofu fmt <path>`.*

### Gate 2: Security & Misconfiguration Scan (Trivy)
```bash
trivy config --skip-check-update --severity HIGH,CRITICAL terraform-modules/parts/<path_to_module>
```
*Ensure 0 HIGH or CRITICAL findings.*

### Gate 3: Zero-Cloud Unit Test Execution
```bash
cd terraform-modules/parts/<path_to_module>
tofu init -backend=false
tofu test
```
*Expected: All run blocks pass in < 2 seconds without hitting external cloud APIs.*

---

## 4. How to Test Changes in Terragrunt Without Releasing

To verify how the updated module behaves inside a real Terragrunt deployment **without waiting for a Git tag release**:

Use the `TG_SOURCE` local override mechanism:
```bash
cd terragrunt/deployments/development/zedcloud-madmax/cluster
TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
```
* **What happens:** Terragrunt bypasses the pinned `?ref=...` Git tag and evaluates the plan directly against your local workspace copy.
* **Safety:** State remains unchanged.

---

## 5. Commit Standards (Mandatory for Release Please)

Releases and changelogs are driven by Conventional Commits. Use the appropriate format:

* **New Feature (Triggers MINOR bump, e.g., v1.1.0 -> v1.2.0):**
  `feat(<module-scope>): add karpenter node role support`
* **Bug Fix (Triggers PATCH bump, e.g., v1.1.0 -> v1.1.1):**
  `fix(<module-scope>): resolve invalid cidr regex pattern`
* **Breaking Change (Triggers MAJOR bump, e.g., v1.1.0 -> v2.0.0):**
  `feat(<module-scope>)!: change default cidr range requirement`

Valid scopes match package names: `aws-eks`, `irsa-role`, `s3-bucket`, `rds-postgres`, `sandbox-test`.

---

## 6. How to Promote and See Live Results on GitHub

1. Push your branch and open a PR.
2. Verify **Matrix CI** status:
   * `Lint, Docs & Security`
   * `Unit Test (<module_name>)`
3. Merge PR into `main`.
4. Observe **Release Please**:
   * Inspect the automatically generated `chore: release main` PR.
   * Upon merging the Release PR, check [Releases Page](https://github.com/xandrei-zededa/sre-versioning-sandbox/releases) for the new immutable Git tag.
5. Promote to Canary/Dev:
   * Navigate to [Dependency Dashboard](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/4).
   * Check the box next to your development cluster to generate the version bump PR.
