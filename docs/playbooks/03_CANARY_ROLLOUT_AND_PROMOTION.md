# Playbook 03: Canary Rollout & Promotion Across Clusters

## Context & Motivation
Promoting a new module version across 27 clusters must be staged to minimize blast radius:
`Canary Dev (madmax)` $\rightarrow$ `Pre-Prod Staging` $\rightarrow$ `Production`.

---

## Step-by-Step Procedure

### 1. View Available Updates
Navigate to **[Issue #18: Dependency Dashboard](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)**.  
Renovate automatically groups clusters into stages:
* `Canary Dev Clusters`
* `Staging Clusters`
* `Production Clusters`

### 2. Stage 1: Promote Canary Dev (`madmax`)
1. Review the open Canary PR created by Renovate:
   `chore(deps): update dev clusters (madmax/alpha) to v1.3.0`
2. Inspect the diff in `deployments/development/zedcloud-madmax/cluster/terragrunt.hcl`.
3. Check CI checks and Atlantis plan outputs.
4. Merge the PR. Dev is now running `v1.3.0`.
5. Observe cluster telemetry, Karpenter pods, and system metrics for 24–48 hours.

### 3. Stage 2: Promote Staging
1. Once Dev is validated, review the Staging PR:
   `chore(deps): update staging clusters to v1.3.0`
2. Run automated smoke tests against staging services.
3. Merge Staging PR.

### 4. Stage 3: Promote Production
1. Review the Production PR:
   `chore(deps): update production clusters to v1.3.0`
2. Verify that `change_summary` contains 0 unexpected resource destructions.
3. Apply during standard maintenance or normal deployment windows.
4. Production is safely updated.

### 5. Post-Promotion State
Upon merging all environment PRs:
* Renovate triggers automatically on PR close.
* The Dependency Dashboard updates to:
  `This repository currently has no open or pending branches.`
