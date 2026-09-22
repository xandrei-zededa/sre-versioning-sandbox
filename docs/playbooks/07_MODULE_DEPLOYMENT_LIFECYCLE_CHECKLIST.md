# Operational Checklist: Creating, Deploying & Promoting Modules

Follow this 4-step sequence to guarantee every new module is immediately tracked, versioned, and visible in the fleet dashboard without blind spots.

---

## The Complete Lifecycle (4 Steps)

```text
[ Step 1: Scaffold Module ]
  └── terraform-modules/parts/<domain>/<name>/
  └── Add code + tests/unit.tftest.hcl (Zero-Cloud Mock)

[ Step 2: Register in Release Manifests ]
  └── release-please-config.json (define package)
  └── .release-please-manifest.json (initial version 1.0.0)

[ Step 3: Connect to at least ONE Deployment (CRITICAL!) ]
  └── terragrunt/deployments/playground/<name>/terragrunt.hcl OR dev/<cluster>/
  └── Pin to initial release tag: ?ref=modules/<name>-v1.0.0
  * WHY: Renovate only tracks dependencies that are actively used in deployments!
  * If a module is not sourced anywhere, it is an "orphan" and will not appear in Issue #18.

[ Step 4: Commit & Merge ]
  └── git commit -m "feat(<name>): initial release"
  └── Release Please cuts v1.0.0 tag -> Renovate immediately tracks future bumps!
```

---

## Summary of Invariants
1. **No Orphan Modules:** A newly versioned module should always have a consumer (either in `playground/` or in a dev cluster like `madmax`).
2. **Local Pre-Commit Hook:** Always run before push to catch formatting and syntax issues in 0.6 seconds.
3. **Inspect Active Usage:** Run `terragrunt list --tree --working-dir terragrunt/deployments` to see the live fleet tree.
