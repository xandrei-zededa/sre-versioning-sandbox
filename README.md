# Terraform/Terragrunt Monorepo Architecture & Operations Manual

[![CI](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml)
[![Release Please](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml)

> **Audience:** Platform Engineers, SREs, and Infrastructure Developers.
> **Purpose:** Practical, end-to-end reference architecture explaining how module semantic versioning, automated releases, zero-cloud unit testing, and staged canary promotions work across a fleet of 27 Kubernetes clusters without downtime or production risk.

---

## Table of Contents
1. [The Problem: Why Relative Paths Fail at Scale](#1-the-problem-why-relative-paths-fail-at-scale)
2. [Target Architecture: Semantic Module Versioning](#2-target-architecture-semantic-module-versioning)
3. [Core Toolchain Roles & Responsibilities](#3-core-toolchain-roles--responsibilities)
4. [Scenario 1: Developing a Module Feature (Zero-Cloud Mocking)](#4-scenario-1-developing-a-module-feature-zero-cloud-mocking)
5. [Scenario 2: Previewing Terragrunt Plans Locally Before Releasing (`TG_SOURCE`)](#5-scenario-2-previewing-terragrunt-plans-locally-before-releasing-tg_source)
6. [Scenario 3: Commits & Pull Requests (Matrix CI, Trivy, Semantic Linter)](#6-scenario-3-commits--pull-requests-matrix-ci-trivy-semantic-linter)
7. [Scenario 4: How Automated Releases Work (Release Please)](#7-scenario-4-how-automated-releases-work-release-please)
8. [Scenario 5: Staged Canary Rollout Across Clusters (Renovate)](#8-scenario-5-staged-canary-rollout-across-clusters-renovate)
9. [Scenario 6: Running Different Module Versions in Different Dev Clusters](#9-scenario-6-running-different-module-versions-in-different-dev-clusters)
10. [Scenario 7: Emergency 30-Second Rollback Protocol](#10-scenario-7-emergency-30-second-rollback-protocol)
11. [Scenario 8: GitHub Actions Workflow Approval Policy](#11-scenario-8-github-actions-workflow-approval-policy)
12. [Quick Reference Cheat Sheet](#12-quick-reference-cheat-sheet)

---

## 1. The Problem: Why Relative Paths Fail at Scale

### Historical State (The Anti-Pattern)
In a traditional monorepo layout, modules live in `terraform-modules/parts/aws/aws_eks/`.
All 27 environments (including production cluster `tmna`, staging, and development cluster `madmax`) reference this directory using local filesystem paths:

```hcl
# terragrunt/deployments/production/tmna/cluster/terragrunt.hcl
terraform {
  source = "../../../../../terraform-modules//parts/aws/aws_eks"
}
```

### The "Russian Roulette" Failure Mode
```text
  [ Engineer modifies aws_eks ] ──► [ Merges to main for dev cluster madmax ]
                                                │
                 ┌──────────────────────────────┴──────────────────────────────┐
                 ▼                                                             ▼
     [ Dev Cluster: madmax ]                                       [ Production Cluster: tmna ]
     Applies change...                                            Atlantis / CI pulls latest main...
                                                                   💥 DRIFT / BREAKING CHANGE DETECTED!
                                                                   💥 RESULT: Production Outage!
```

1. **Zero Blast Radius Isolation:** Any merge into `main` instantly becomes live code for all 27 clusters simultaneously.
2. **Fear of Refactoring:** Engineers avoid improving shared modules because a single typo can cause a global production outage.
3. **No Staged Canary Rollouts:** It is impossible to promote a module to `madmax`, verify it for a week, promote to `staging`, and only then update `production`.
4. **Painful Rollbacks:** Reverting an outage requires an urgent `git revert` on `main`, creating git merge conflicts for concurrent work.

---

## 2. Target Architecture: Semantic Module Versioning

In this architecture, module source code and cluster deployments are **completely decoupled using immutable Git tags (Semantic Versioning)**.

```text
               terraform-modules/parts/aws/aws_eks
                                │
                    [ Release Please Engine ]
                                │
               ┌────────────────┴────────────────┐
               ▼                                 ▼
   modules/aws-eks-v1.0.0            modules/aws-eks-v1.2.0
        (Stable)                         (New with Karpenter)
               │                                 │
               ▼                                 ▼
    [ Production Clusters ]             [ Dev Cluster: madmax ]
   Pinned to stable v1.0.0             Safely tests v1.2.0 in isolation
   IMMUNE TO COMMITS ON MAIN!          Other 26 clusters remain unaffected!
```

Each cluster's `terragrunt.hcl` explicitly pins an immutable version:
```hcl
terraform {
  source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
}
```
**Core Safety Invariant:** Regardless of how many commits are pushed to `main`, production pulls **strictly tag `v1.0.0`**. Production is permanently protected against unreleased changes.

---

## 3. Core Toolchain Roles & Responsibilities

1. **OpenTofu Mock Provider (`tofu test`):**
   * Built-in native testing engine. Intercepts AWS/GCP API calls in-memory.
   * Validates HCL conditionals, loops, and regex validations locally in **~1.1 seconds** without cloud credentials.
2. **Release Please (Google APIs):**
   * Release management automation. Parses Conventional Commits (`feat:`, `fix:`).
   * Automatically calculates SemVer increments (`1.1.0` $\rightarrow$ `1.2.0`), generates `CHANGELOG.md`, and creates Git tags upon merge. Engineers never tag manually.
3. **Self-Hosted Renovate Runner:**
   * Runs natively inside GitHub Actions on push, PR close, or schedule.
   * Detects new module tags and generates grouped, structured PRs (`Canary Dev` $\rightarrow$ `Staging` $\rightarrow$ `Production`).
4. **Trivy SAST & Destructive Plan Guard:**
   * Scans HCL for open security groups, wildcard IAM permissions, and unencrypted volumes.
   * Blocks execution if `plan` contains destructive actions (`destroy > 0`) against databases or cluster control planes.

---

## 4. Scenario 1: Developing a Module Feature (Zero-Cloud Mocking)

### Task: Add S3 Intelligent-Tiering support to `s3-bucket`

1. Create a feature branch:
   ```bash
   git checkout -b feat/s3-tiering
   ```
2. Modify `terraform-modules/parts/aws/s3-bucket/main.tf`:
   ```hcl
   variable "enable_intelligent_tiering" {
     type        = bool
     description = "Enable S3 Intelligent-Tiering"
     default     = false
   }

   resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
     count  = var.enable_intelligent_tiering ? 1 : 0
     bucket = aws_s3_bucket.this.id
     name   = "EntireBucket"
     tiering {
       access_tier = "ARCHIVE_ACCESS"
       days        = 90
     }
   }
   ```
3. Update `terraform-modules/parts/aws/s3-bucket/tests/unit.tftest.hcl`:
   ```hcl
   mock_provider "aws" {}

   run "verify_tiering_active" {
     command = plan
     variables {
       bucket_name                = "test-bucket"
       enable_intelligent_tiering = true
     }
     assert {
       condition     = length(aws_s3_bucket_intelligent_tiering_configuration.this) == 1
       error_message = "Tiering configuration block must be created"
     }
   }
   ```
4. Run isolated local test:
   ```bash
   cd terraform-modules/parts/aws/s3-bucket
   tofu test
   ```
   **Output:** Executes in **1.1 seconds** with 0 AWS calls. Syntax, conditionals, and assertions are verified locally.

---

## 5. Scenario 2: Previewing Terragrunt Plans Locally Before Releasing (`TG_SOURCE`)

**Common question:** *"I wrote module changes, but the tag is not published yet. How do I inspect `terragrunt plan` on development cluster `madmax`?"*

Use the built-in Terragrunt override environment variable `TG_SOURCE`:

```bash
cd terragrunt/deployments/development/zedcloud-madmax/cluster

# Temporarily override remote Git tag with local disk path:
TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
```

### What Happens:
1. Terragrunt **ignores the remote `?ref=...` Git tag** in `terragrunt.hcl`.
2. It mounts your uncommitted local files from `terraform-modules/` on your disk.
3. It evaluates a real plan diff against the cluster's state.
4. You verify the diff **before** creating a PR or publishing a release.

---

## 6. Scenario 3: Commits & Pull Requests (Matrix CI, Trivy, Semantic Linter)

This repository enforces **Conventional Commits** to automate SemVer calculation.

### Commit Syntax:
```text
<type>(<scope>): <description>
```

| Change Type | Commit Example | Next Version Bump |
| :--- | :--- | :--- |
| New feature or resource | `git commit -m "feat(s3-bucket): add intelligent tiering support"` | **MINOR** (`v1.1.0` $\rightarrow$ `v1.2.0`) |
| Bug fix or correction | `git commit -m "fix(s3-bucket): fix expiration lifecycle days"` | **PATCH** (`v1.1.0` $\rightarrow$ `v1.1.1`) |
| Breaking change | `git commit -m "feat(s3-bucket)!: change required bucket prefix"` | **MAJOR** (`v1.1.0` $\rightarrow$ `v2.0.0`) |

*Allowed scopes:* `aws-eks`, `irsa-role`, `rds-postgres`, `s3-bucket`, `sandbox-test`, `deps`.

### What Runs on PR Creation:
GitHub Actions executes the **Parallel Matrix CI**:
* `OpenTofu Format Check` (`tofu fmt -check`)
* `Trivy Security Scan` (HCL misconfiguration detection)
* `terraform-docs` (Auto-injects inputs/outputs into module README)
* `Unit Tests` (Executes `tofu test` across all modules in parallel)
* `Validate PR Title` (Ensures compliance with Conventional Commits)

Once approved, perform **Squash and Merge** into `main`.

---

## 7. Scenario 4: How Automated Releases Work (Release Please)

Engineers **never** create Git tags or releases manually.

1. When a PR is merged into `main`, the **Release Please** workflow triggers.
2. The engine parses the commit message (e.g. `feat(s3-bucket): ...`).
3. It automatically maintains an open Release PR:
   👉 `chore: release main`
4. This PR automatically:
   * Increments the module version in `.release-please-manifest.json`: `1.1.0 -> 1.2.0`.
   * Appends release notes to `terraform-modules/parts/aws/s3-bucket/CHANGELOG.md`.
5. Merging this Release PR triggers:
   * Git tag creation: **`modules/s3-bucket-v1.2.0`**.
   * Publication of an official **GitHub Release**.

---

## 8. Scenario 5: Staged Canary Rollout Across Clusters (Renovate)

Once `modules/s3-bucket-v1.2.0` is published, deployments must be updated.
The **Self-Hosted Renovate Runner** manages promotions via **[Issue #18: Dependency Dashboard](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)**.

```text
                        New Module Tag Published: v1.2.0
                                       │
                                       ▼
                         [ Self-Hosted Renovate Runner ]
                                       │
       ┌───────────────────────────────┴───────────────────────────────┐
       ▼                                                               ▼
[ Canary PR for Dev Clusters ]                                [ Production Safe ]
PR opened for madmax/alpha.                                   Production is NOT touched.
diff: v1.1.0 -> v1.2.0                                        Awaits manual promotion in dashboard.
```

### Promotion Flow:
1. Review the open Canary PR for Dev Clusters (`madmax`/`alpha`).
2. Verify the 1-line version change, run `terragrunt plan`, and merge.
3. Observe Dev stability for your testing period.
4. Promote Staging and Production by reviewing and merging their respective PRs.

---

## 9. Scenario 6: Running Different Module Versions in Different Dev Clusters

**Real-world scenario:** *Engineer A tests an EKS upgrade on `madmax`, while Engineer B requires stable EKS on `alpha` to test application workloads.*

Because each cluster defines its own `terragrunt.hcl`, versions are completely isolated:

* **Cluster `madmax` (Canary):**
  ```hcl
  # terragrunt/deployments/development/zedcloud-madmax/cluster/terragrunt.hcl
  terraform {
    source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.2.0"
  }
  ```
* **Cluster `alpha` (Stable Dev):**
  ```hcl
  # terragrunt/deployments/development/zedcloud-alpha/cluster/terragrunt.hcl
  terraform {
    source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
  }
  ```
Both coexist in the same repository simultaneously without dependency conflicts.

---

## 10. Scenario 7: Emergency 30-Second Rollback Protocol

### Problem:
A new module version `v1.2.0` was applied to Production, and an unexpected cloud provider regression is observed.

### Rollback Execution (30 Seconds):
1. Open `terragrunt/deployments/production/tmna/cluster/terragrunt.hcl`.
2. Change the tag reference back to the known-good version:
   ```hcl
   # Previous (failing):
   source = "...?ref=modules/aws-eks-v1.2.0"

   # Rollback (safe):
   source = "...?ref=modules/aws-eks-v1.1.0"
   ```
3. Run `terragrunt apply` (via Atlantis or local CLI).
   Infrastructure immediately reverts to the exact previous state. No code edits or git reverts in `terraform-modules/` are needed.

---

## 11. Scenario 8: GitHub Actions Workflow Approval Policy

If you encounter:
> *«1 workflow awaiting approval — This workflow requires approval from a maintainer.»*

### Why It Appears:
GitHub applies a security policy for public repositories: when automated PRs are created by bot tokens, GitHub holds workflows until an owner approves execution to prevent runner quota abuse.

### Permanent Resolution:
1. Navigate to: **Settings $\rightarrow$ Actions $\rightarrow$ General**.
2. Scroll to **Fork pull request workflows from outside collaborators**.
3. Select:
   👉 **`Require approval for first-time contributors with no prior commits`**.

Automated PRs from Renovate will now trigger CI runs immediately without pauses.

---

## 12. Quick Reference Cheat Sheet

| Task | Command / Location | Execution Time |
| :--- | :--- | :--- |
| **Run module unit tests** | `cd terraform-modules/parts/... && tofu test` | **~1.1s** (0 cloud calls) |
| **Check HCL formatting** | `tofu fmt -check terraform-modules` | **0.1s** |
| **Scan security misconfigurations** | `trivy config --severity HIGH,CRITICAL terraform-modules` | **~0.8s** |
| **Preview Terragrunt plan locally** | `TG_SOURCE=<module_path> terragrunt plan` | Standard Terragrunt |
| **Run all pre-commit hooks** | `pre-commit run --all-files` | **~3s** |
| **Interactive E2E demo script** | `./scripts/demo-walkthrough.sh` | **~5s** |
| **Central Dependency Dashboard** | **[Issue #18](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)** | Web UI |
