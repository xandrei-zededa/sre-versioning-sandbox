# SRE Platform Terraform & Terragrunt Monorepo Engineering Manual

[![CI](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml)
[![Release Please](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml)

> **Audience:** Platform Engineers, SREs, and DevOps Specialists.
> **Repository:** [xandrei-zededa/sre-versioning-sandbox](https://github.com/xandrei-zededa/sre-versioning-sandbox)
> **Status:** Fully functional reference implementation for managing 27 Kubernetes clusters across multi-region cloud infrastructure without outage risks.

---

## Table of Contents
1. [The Core Problem: Why Relative Paths Fail at Scale](#1-the-core-problem-why-relative-paths-fail-at-scale)
2. [Target Architecture: Semantic Module Versioning](#2-target-architecture-semantic-module-versioning)
3. [Toolchain Roles & Responsibilities](#3-toolchain-roles--responsibilities)
4. [Scenario 1: Creating a New Module (Zero-Cloud Mocking)](#4-scenario-1-creating-a-new-module-zero-cloud-mocking)
5. [Scenario 2: Modifying an Existing Module (Local `TG_SOURCE` Preview)](#5-scenario-2-modifying-an-existing-module-local-tg_source-preview)
6. [Scenario 3: Breaking Changes & Major Releases (`v2.0.0`)](#6-scenario-3-breaking-changes--major-releases-v200)
7. [Scenario 4: Atomic Multi-Package Pull Requests (Multi-Release)](#7-scenario-4-atomic-multi-package-pull-requests-multi-release)
8. [Scenario 5: Granular Single-Cluster Upgrades (Issue #18 Dashboard)](#8-scenario-5-granular-single-cluster-upgrades-issue-18-dashboard)
9. [Scenario 6: Running Different Module Versions Across Dev Clusters](#9-scenario-6-running-different-module-versions-across-dev-clusters)
10. [Scenario 7: Emergency 30-Second Rollback Protocol](#10-scenario-7-emergency-30-second-rollback-protocol)
11. [Scenario 8: Shift-Left Security & Destructive Plan Guard](#11-scenario-8-shift-left-security--destructive-plan-guard)
12. [Scenario 9: CI Performance, Provider Caching & Local Pre-Commit](#12-scenario-9-ci-performance-provider-caching--local-pre-commit)
13. [Deep Dive: How OpenTofu Mocks Work Under the Hood](#13-deep-dive-how-opentofu-mocks-work-under-the-hood)
14. [Deep Dive: What Issue #18 is and How It Functions](#14-deep-dive-what-issue-18-is-and-how-it-functions)
15. [Quick Reference Cheat Sheet](#15-quick-reference-cheat-sheet)

---

## 1. The Core Problem: Why Relative Paths Fail at Scale

### Historical Antipattern (Relative Paths)
In a shared monorepo, 27 clusters traditionally connect to module directories via relative filesystem paths:
```hcl
# terragrunt/deployments/production/tmna/cluster/terragrunt.hcl
terraform {
  source = "../../../../../terraform-modules//parts/aws/aws_eks"
}
```

### The "Russian Roulette" Disaster Scenario:
```text
  [ Developer modifies aws_eks ] ──► [ Merges to main for dev cluster madmax ]
                                                 │
                 ┌───────────────────────────────┴───────────────────────────────┐
                 ▼                                                               ▼
     [ Dev Cluster: madmax ]                                         [ Production Cluster: tmna ]
     Intended test rollout...                                        Atlantis / CI pulls latest main...
                                                                     💥 UNINTENDED DRIFT OR DELETION!
                                                                     💥 RESULT: Production Outage!
```

* **Immediate Global Impact:** Every commit merged into `main` instantly mutates the source code for all 27 clusters simultaneously.
* **No Canary Rollouts:** It is impossible to safely test a new module version on a single cluster for a few days without affecting production.
* **Rollback Hell:** If production breaks, engineers must rush a `git revert` into `main`, creating massive git conflicts for other ongoing work.

---

## 2. Target Architecture: Semantic Module Versioning

In this architecture, module source code and cluster deployments are **strictly decoupled using immutable Git tags (Semantic Versioning)**.

```text
               terraform-modules/parts/aws/aws_eks
                                │
                    [ Release Please Engine ]
                                │
               ┌────────────────┴────────────────┐
               ▼                                 ▼
   modules/aws-eks-v1.0.0            modules/aws-eks-v1.3.0
        (Stable)                         (New with Karpenter)
               │                                 │
               ▼                                 ▼
    [ Production Clusters ]             [ Dev Cluster: madmax ]
   Pinned to stable v1.0.0             Safely tests v1.3.0 in isolation
   IMMUNE TO COMMITS ON MAIN!          Other 26 clusters remain unaffected!
```

Each cluster's `terragrunt.hcl` explicitly pins an immutable version:
```hcl
terraform {
  source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
}
```
**Safety Invariant:** Regardless of what gets committed or refactored on `main`, production pulls **strictly tag `v1.0.0`**. Production is permanently immune to unreleased changes.

---

## 3. Toolchain Roles & Responsibilities

1. **OpenTofu Mock Provider (`tofu test`):**
   * Built-in testing engine that intercepts cloud API calls in memory.
   * Runs unit tests across all modules in **~1.1 seconds** locally without AWS credentials, network calls, or costs.
2. **Release Please (Google APIs):**
   * Automated release manager driven by Conventional Commits (`feat:`, `fix:`).
   * Automatically calculates SemVer, updates `CHANGELOG.md`, and creates Git tags upon merge. Engineers never tag manually.
3. **Self-Hosted Renovate Runner:**
   * Runs natively inside GitHub Actions on push, PR close, or schedule.
   * Manages single-cluster or grouped version promotions via [Issue #18 (Dependency Dashboard)](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18).
4. **Trivy SAST & Destructive Plan Guard:**
   * Scans HCL for open security groups, wildcard IAM roles, and unencrypted volumes.
   * Prevents PR merges if a plan contains destructive resource deletions (`destroy > 0`).

---

## 4. Scenario 1: Creating a New Module (Zero-Cloud Mocking)

1. Create directory structure:
   ```bash
   mkdir -p terraform-modules/parts/aws/sqs-queue/tests
   ```
2. Write module code (`main.tf`):
   ```hcl
   terraform {
     required_version = ">= 1.6.0"
     required_providers {
       aws = { source = "hashicorp/aws", version = "~> 6.0" }
     }
   }
   variable "queue_name" {
     type = string
     validation {
       condition     = can(regex("^[a-zA-Z0-9_-]+$", var.queue_name))
       error_message = "Invalid characters in queue name."
     }
   }
   resource "aws_sqs_queue" "this" {
     name = var.queue_name
   }
   ```
3. Add native unit test (`tests/unit.tftest.hcl`):
   ```hcl
   mock_provider "aws" {}
   variables { queue_name = "dead-letter-queue" }
   run "verify_queue" {
     command = plan
     assert {
       condition     = aws_sqs_queue.this.name == "dead-letter-queue"
       error_message = "Name mismatch"
     }
   }
   ```
4. Register in `release-please-config.json` and `.release-please-manifest.json`.
5. Pre-commit validates formatting and tests in **0.6s**. Open PR $\rightarrow$ CI automatically detects the module $\rightarrow$ Release Please tags `v1.0.0` on merge.

---

## 5. Scenario 2: Modifying an Existing Module (Local `TG_SOURCE` Preview)

**Question:** *"I changed an EKS module, but the tag is not published yet. How do I inspect `terragrunt plan` on dev cluster `madmax`?"*

Use the Terragrunt `TG_SOURCE` override:
```bash
cd terragrunt/deployments/development/zedcloud-madmax/cluster
TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
```
* **What happens:** Terragrunt temporarily bypasses the Git tag and mounts your local workspace files from disk.
* **Safety:** State remains unchanged, and no remote tag is touched.

---

## 6. Scenario 3: Breaking Changes & Major Releases (`v2.0.0`)

When introducing breaking changes (e.g., adding a mandatory variable without a default):
1. Write commit with `!` or `BREAKING CHANGE:` footer:
   ```bash
   git commit -m "feat(sqs-queue)!: require mandatory vpc id parameter for enterprise isolation"
   ```
2. Release Please recognizes the breaking change:
   * Skips minor bump and jumps directly from `v1.1.0` to **`v2.0.0`**.
   * Creates release tag `modules/sqs-queue-v2.0.0`.
   * Highlights breaking changes in `CHANGELOG.md`.

---

## 7. Scenario 4: Atomic Multi-Package Pull Requests (Multi-Release)

If you modify **multiple modules simultaneously** in one PR (e.g. updating both `aws_eks` and `irsa_role`):
1. Commit changes touching both modules:
   ```bash
   git commit -m "feat(deps): atomic update to aws-eks and irsa-role modules"
   ```
2. Release Please tracks file paths independently and generates **two separate releases**:
   * `modules/aws-eks: v1.3.0`
   * `modules/irsa-role: v1.2.0`
3. Both tags are published simultaneously with 0 cross-package pollution.

---

## 8. Scenario 5: Granular Single-Cluster Upgrades (Issue #18 Dashboard)

To upgrade **only a specific cluster** (e.g., `madmax` only, leaving `alpha` and `production` intact):

1. Open **[Issue #18: Dependency Dashboard](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)**.
2. Select the specific cluster checkbox:
   * `- [ ] chore(deps): update Cluster: madmax to v1.3.0`
3. Renovate generates a targeted PR affecting **only** `terragrunt/deployments/development/zedcloud-madmax/**`.
4. Review the 1-line diff, verify the plan, and merge.
5. Other clusters remain on their pinned versions until explicitly upgraded.

---

## 9. Scenario 6: Running Different Module Versions Across Dev Clusters

Because every cluster defines its own `terragrunt.hcl`, different clusters run different versions without friction:

* **Cluster `madmax` (Canary):**
  ```hcl
  source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.3.0"
  ```
* **Cluster `alpha` (Stable Baseline):**
  ```hcl
  source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
  ```
Both clusters coexist in the same repository simultaneously without version conflicts.

---

## 10. Scenario 7: Emergency 30-Second Rollback Protocol

If a cloud provider regression occurs in production after an upgrade:
1. Open `terragrunt/deployments/production/zedcloud-production/cluster/terragrunt.hcl`.
2. Revert the tag reference:
   ```hcl
   # Failing:
   source = "...?ref=modules/aws-eks-v1.3.0"

   # Revert:
   source = "...?ref=modules/aws-eks-v1.2.0"
   ```
3. Run `terragrunt apply`. The infrastructure immediately restores to the previous stable state. No git reverts in `terraform-modules/` are needed.

---

## 11. Scenario 8: Shift-Left Security & Destructive Plan Guard

* **Trivy SAST Scan:** Runs in CI and flags open CIDR blocks (`0.0.0.0/0`), wildcard IAM policies, and unencrypted EBS volumes.
* **Destructive Plan Guard (`destructive-guard.yml`):** Automatically evaluates PR plans against deployment directories. If a change attempts to remove critical resources (`aws_eks_cluster`, `aws_db_instance`, `aws_s3_bucket`), the PR is immediately blocked.

---

## 12. Scenario 9: CI Performance, Provider Caching & Local Pre-Commit

* **Local Pre-Commit Hook (0.6s):** Fast, non-blocking pre-commit validates whitespace, commit messages, and HCL formatting before code leaves your machine.
* **Dynamic Matrix CI:** Automatically finds all `*.tftest.hcl` files and executes tests across all modules in parallel in **~14 seconds**.
* **Provider Caching (`TF_PLUGIN_CACHE_DIR`):** The 400MB AWS provider is cached via `actions/cache@v4`. `tofu init` completes in **0.2 seconds** from local cache.

---

## 13. Deep Dive: How OpenTofu Mocks Work Under the Hood

### Automatic Resource Mocking (Out of the Box)
When you write `mock_provider "aws" {}`, OpenTofu downloads the official provider schema and automatically generates in-memory mock objects for **every AWS resource**. You do not write mock schemas manually.

### Data Source Overrides (`mock_data`)
The only manual requirement is for `data` blocks returning JSON strings (e.g. IAM policy documents):
```hcl
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\"}" }
  }
}
```

---

## 14. Deep Dive: What Issue #18 is and How It Functions

**[Issue #18](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)** is the central control dashboard for cluster upgrades:

| Section in Issue #18 | Meaning | Required Action |
| :--- | :--- | :--- |
| **`Rate-Limited`** | New version available; bot is waiting for your signal. | Click `[x]` on target cluster to generate a single upgrade PR. |
| **`Open`** | Upgrade PR is already created and awaiting review. | Click the PR link, inspect plan diff, and merge! |
| **`Up-to-Date`** | All deployments are synced to latest releases. | No action required. |

---

## 15. Quick Reference Cheat Sheet

| Action | Command / Location | Expected Duration |
| :--- | :--- | :--- |
| **Run module unit tests** | `cd terraform-modules/parts/... && tofu test` | **~1.1s** (0 cloud calls) |
| **Check HCL formatting** | `tofu fmt -check terraform-modules` | **0.1s** |
| **Scan security (Trivy)** | `trivy config --severity HIGH,CRITICAL terraform-modules` | **~0.8s** |
| **Preview plan with local code** | `TG_SOURCE=<path> terragrunt plan` | Standard Terragrunt |
| **Run local pre-commit** | `pre-commit run --all-files` | **0.6s** |
| **Inspect fleet hierarchy** | `terragrunt list --tree --working-dir terragrunt/deployments` | Instant CLI tree |
| **Cluster Upgrade Dashboard** | **[Issue #18](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)** | Web UI |
