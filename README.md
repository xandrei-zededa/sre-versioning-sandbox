# Engineering Operations Manual: Terraform/Terragrunt Monorepo Architecture

[![CI](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml)
[![Release Please](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml)

> **Audience:** Platform Engineers, SREs, and DevOps Specialists.
> **Repository:** [xandrei-zededa/sre-versioning-sandbox](https://github.com/xandrei-zededa/sre-versioning-sandbox)

---

## 1. Core Principles & Safety Invariants

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│ INVARIANT 1: Zero Production Blast Radius                                      │
│ Direct merges to main NEVER alter production state. Deployments pin immutable  │
│ Git tags: ?ref=modules/<name>-v<semver>.                                       │
├────────────────────────────────────────────────────────────────────────────────┤
│ INVARIANT 2: Zero-Cloud Unit Testing                                           │
│ All HCL logic, conditionals, and regex rules are verified in ~1 second via     │
│ OpenTofu mock_provider. No AWS tokens, network calls, or costs.                │
├────────────────────────────────────────────────────────────────────────────────┤
│ INVARIANT 3: Dynamic Zero-Maintenance CI                                        │
│ CI auto-discovers all modules with *.tftest.hcl. No hardcoded lists.           │
├────────────────────────────────────────────────────────────────────────────────┤
│ INVARIANT 4: Staged Canary Promotion                                           │
│ Version upgrades flow through Canary Dev -> Staging -> Production.             │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. All Engineering Scenarios (Step-by-Step)

### Scenario A: Creating a New Module
1. Create directory: `terraform-modules/parts/<domain>/<name>/tests/`
2. Add `main.tf` with typed variables and validation rules.
3. Add `tests/unit.tftest.hcl` with `mock_provider "aws" {}`.
4. Register package in `release-please-config.json` and `.release-please-manifest.json`.
5. Pre-commit automatically tests and formats. Open PR $\rightarrow$ CI dynamically detects the new module $\rightarrow$ Release Please tags `v1.0.0` on merge.

### Scenario B: Modifying an Existing Module
1. Create branch: `git checkout -b feat/add-sqs-fifo`
2. Update HCL code and add assertions in `tests/unit.tftest.hcl`.
3. Preview against real deployment **without releasing**:
   ```bash
   cd terragrunt/deployments/development/zedcloud-madmax/cluster
   TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
   ```
4. Commit: `git commit -m "feat(aws-eks): add fifo support"`
5. Merge $\rightarrow$ Release Please cuts `v1.3.0` $\rightarrow$ Production remains untouched on `v1.2.0`.

### Scenario C: Canary Rollout & Cluster Promotion
1. Check [Dependency Dashboard (Issue #18)](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18).
2. Merge the **Canary Dev PR** (`madmax`/`alpha`).
3. Verify telemetry for 24–48 hours.
4. Merge the **Production PR**.
5. Dashboard automatically clears all merged items upon PR close.

### Scenario D: Emergency 30-Second Rollback
If a regression occurs in Production:
1. Open `terragrunt/deployments/production/zedcloud-production/cluster/terragrunt.hcl`.
2. Change `ref=modules/aws-eks-v1.3.0` back to `ref=modules/aws-eks-v1.2.0`.
3. Run `terragrunt apply`. The cluster instantly restores to the previous stable state.

---

## 3. Toolchain & Command Reference

| Action | Native Command | Target / Scope |
| :--- | :--- | :--- |
| **Discover fleet structure** | `terragrunt list --tree --working-dir terragrunt/deployments` | All 27 clusters |
| **Run local unit tests** | `tofu test` | Inside module folder |
| **Format all HCL code** | `tofu fmt -recursive terraform-modules` | Entire repo |
| **Scan security (Trivy)** | `trivy config --severity HIGH,CRITICAL terraform-modules` | Offline SAST |
| **Run pre-commit checks** | `pre-commit run --all-files` | Staged commits |
