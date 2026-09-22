# SRE Platform Terraform Modules Monorepo & Versioning Architecture

[![CI](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/ci.yml)
[![Release Please](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml/badge.svg)](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/workflows/release-please.yml)

> **Documentation in Russian / Документация на русском языке:**  
> 👉 **[Полное практическое руководство (README_RU.md)](./README_RU.md)**

---

## 1. Executive Summary

This repository represents the production-ready reference architecture for managing Terraform/OpenTofu modules in a large-scale monorepo supporting **27 Kubernetes clusters** across Multi-Region AWS environments.

### The Problem Solved
* **Before:** Modules were consumed via relative filesystem paths (`source = "../../../../../terraform-modules//parts/aws/aws_eks"`). Every merge into `main` instantly impacted all 27 clusters simultaneously without canary isolation.
* **After:** Modules are semantically versioned packages pinned by immutable Git tags (`?ref=modules/aws-eks-v1.2.0`). Production clusters remain 100% immune to unreleased changes in `main`.

---

## 2. Key Architecture Pillars

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 1. Zero-Cloud Mock Testing (tofu test)                                          │
│    - Mock provider intercepts AWS API calls in-memory                           │
│    - Validates HCL logic, count conditions, and regex rules in ~1 second        │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 2. Automated SemVer Tagging (Release Please)                                    │
│    - Conventional Commits (feat, fix) trigger automatic releases                │
│    - Independent versioning per module without cross-package pollution          │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 3. Staged Canary Rollout (Self-Hosted Renovate Runner)                          │
│    - Controls version promotion: Canary Dev (madmax) -> Staging -> Production   │
│    - Centralized interactive Dependency Dashboard in GitHub Issues              │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 4. Shift-Left Security & Guardrails                                             │
│    - Trivy SAST scans HCL for IAM misconfigurations in CI                       │
│    - Destructive Plan Guard blocks accidental cluster/database teardowns        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. End-to-End Operational Workflow

```text
[ Step 1: Local Module Development ]
  $ cd terraform-modules/parts/aws/aws_eks
  $ tofu test   # Instant test execution on mocks (1.1s)

[ Step 2: Local Terragrunt Dry-Run Preview ]
  $ cd terragrunt/deployments/development/zedcloud-madmax/cluster
  $ TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
  # Bypasses Git tag temporarily to preview local changes directly against dev state!

[ Step 3: Conventional Commit & PR ]
  $ git commit -m "feat(aws-eks): add support for karpenter node role"
  # Parallel Matrix CI runs: fmt, Trivy, terraform-docs, and unit tests

[ Step 4: Automated Tagging & Canary Promotion ]
  1. Merge PR into main.
  2. Release Please automatically publishes tag: modules/aws-eks-v1.3.0.
  3. Renovate generates canary bump PR for dev clusters (madmax/alpha).
  4. Verify Dev stability -> Promote to Staging -> Promote to Production.
```

---

## 4. Live Reference Artifacts

* **Live GitHub Releases:** [Releases Page](https://github.com/xandrei-zededa/sre-versioning-sandbox/releases)
* **Live Dependency Dashboard:** [Issue #18](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)
* **Live Parallel Matrix CI:** [GitHub Actions](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions)
* **AI & LLM Operational Guidelines:** [AGENTS.md](./AGENTS.md)
