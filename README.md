# SRE Platform Terraform Modules Monorepo & Versioning Architecture

[![CI](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml)
[![Release Please](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml)

> Reference implementation and live sandbox demonstrating semantic versioning, automated releases (Release Please), isolated zero-cloud testing (`tofu test` with mocking), and staged canary rollout across multi-cluster fleet.

---

## 1. Executive Summary: Why This Matters

### Current Problem (Relative Path Anti-Pattern)
Across 27 clusters and 100+ Terragrunt configurations, modules are currently sourced via relative filesystem paths:
```hcl
source = "../../../../../terraform-modules//parts/aws/aws_eks"
```
* **"Russian Roulette" Deployment:** Any merge into `main` instantly and simultaneously affects **all 27 clusters**.
* **Zero Blast Radius Isolation:** Impossible to test module changes safely in Dev (`madmax`) without exposing Production (`tmna`) to immediate drift or breaking changes.
* **Rollback Hell:** Rolling back an outage requires urgent and risky `git revert` across the shared codebase.

### Target Solution (This Repository)
* **Pinned Semantic Tags:** Clusters pin immutable tags: `?ref=modules/aws-eks-v1.1.0`. Production is immune to changes in `main`.
* **Zero-Cloud Mocking (`tofu test`):** Engineers validate HCL conditionals, loops, and regex rules locally in **1.1 seconds** without AWS credentials.
* **Automated Releases (Release Please):** Conventional Commits trigger automatic SemVer bumps, tag generation, and changelogs.
* **Staged Canary Rollout:** Controlled promotion via Renovate Dependency Dashboard (`Dev` -> `Staging` -> `Production`).

---

## 2. Repository Layout

```text
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Matrix CI: fmt, Trivy SAST, terraform-docs, tofu test
│       ├── release-please.yml     # Automated SemVer releases and tagging
│       └── semantic-pr.yml        # Conventional Commits PR title validation
├── terraform-modules/
│   └── parts/
│       └── aws/
│           ├── aws_eks/           # EKS cluster, node groups, WAF, Karpenter
│           ├── irsa_role/         # IAM OIDC service account roles
│           ├── rds-postgres/      # PostgreSQL RDS instances
│           └── s3-bucket/         # S3 buckets with versioning
├── terragrunt/
│   └── deployments/
│       ├── development/           # Canary environment (zedcloud-madmax)
│       ├── staging/               # Pre-production validation (zedcloud-staging)
│       └── production/            # Production cluster (zedcloud-production)
├── release-please-config.json     # Release Please package definitions
├── .release-please-manifest.json  # Current version tracking per module
└── renovate.json5                 # Renovate regex manager & canary grouping
```

---

## 3. Developer Workflow ("Zero Friction")

### Step 1: Local Development & Isolated Testing
No cloud credentials or network calls required:
```bash
cd terraform-modules/parts/aws/aws_eks
tofu test
```
*Executes unit tests with `mock_provider` in ~1 second.*

### Step 2: Test Terragrunt Against Local Code (Without Releasing)
```bash
cd terragrunt/deployments/development/zedcloud-madmax/cluster
TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
```
*Terragrunt evaluates diff against your uncommitted local module code.*

### Step 3: Conventional Commit & Pull Request
```bash
git checkout -b feat/add-karpenter-support
git commit -m "feat(aws-eks): add karpenter node role support"
git push -u origin feat/add-karpenter-support
```
GitHub Actions runs the **Parallel Matrix CI** (Lint, Trivy security scan, and unit tests).

### Step 4: Automated Tagging & Promotion
* Once merged into `main`, **Release Please** automatically generates a Release PR, bumps the version (`v1.0.0` -> `v1.1.0`), creates Git tag `modules/aws-eks-v1.1.0`, and writes `CHANGELOG.md`.
* Engineers promote the version to `madmax`, verify stability, and then promote to Production via the **[Dependency Dashboard](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/4)**.

---

## 4. Live Demonstration & Verification

Run the end-to-end interactive simulation script locally:
```bash
./scripts/demo-walkthrough.sh
```

---

## 5. Active Live Resources

* **Live GitHub Releases:** [Releases Page](https://github.com/xandrei-zededa/sre-versioning-sandbox/releases)
* **Live Dependency Dashboard:** [Issue #4](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/4)
* **Live CI Matrix Runs:** [GitHub Actions](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions)
