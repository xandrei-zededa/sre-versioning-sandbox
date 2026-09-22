# FAQ & Practical Guide: Understanding the Dependency Dashboard (Issue #18)

> **"Why does Issue #18 exist and how does it actually work?"**
> This guide explains the concept in plain English without marketing fluff.

---

## 1. What is Issue #18? (The "Remote Control" for Cluster Upgrades)

Think of **Issue #18** not as a bug report, but as an **interactive dashboard / remote control**.

### The Problem It Solves:
When a new module version is released (e.g. `aws-eks: v1.3.0`):
* **BAD WAY (Bot Spam):** A bot immediately opens 27 Pull Requests for all 27 clusters. Your email and Slack explode with notifications. Nobody reviews them.
* **OUR WAY (Dashboard):** The bot **does not spam**. Instead, it lists available upgrades inside **Issue #18** as simple checkboxes.

---

## 2. How to Read Issue #18: The 3 Sections Explained

When you open [Issue #18](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18), you see up to 3 sections:

### Section A: `Rate-Limited` (New versions waiting for your permission)
```markdown
## Rate-Limited
- [ ] chore(deps): update staging clusters to v1.3.0
```
* **What it means:** A new version `v1.3.0` was released, but the bot has NOT opened a Pull Request yet because it is waiting for an engineer's signal.
* **What happens when you click `[x]`:** The bot wakes up within ~20 seconds and **creates a Pull Request** to upgrade staging.

---

### Section B: `Open` (PRs that are already created and waiting for review)
```markdown
## Open
- [ ] [chore(deps): update dev clusters to v1.3.0](../pull/39)
```
* **What it means:** A Pull Request is **already open and waiting for your review**.
* **What you should do:** Click the link `[chore(deps)...]`, review the diff, and click **Merge**!
* **What the checkbox does here:** Clicking `[x]` here tells the bot: *"Rebase this PR branch against latest main"*.

---

### Section C: `All dependencies are up-to-date!`
```markdown
This repository currently has no open or pending branches.
```
* **What it means:** All clusters are running the latest versions. Zero action required!

---

## 3. The 3-Step Daily Workflow

When you want to update your clusters:

```text
1. Open Issue #18
   └── See which clusters have updates available.

2. Stage 1: Upgrade Dev (madmax)
   └── Click checkbox for Canary Dev -> Review and merge the Dev PR.
   └── Verify stability in your dev cluster for a couple of days.

3. Stage 2: Upgrade Staging & Production
   └── Click checkbox for Production -> Review diff -> Merge!
   └── Issue #18 automatically clears out the merged items.
```

---

## 4. Why You Never Have to Worry About Breaking Production

Even if you merge 20 PRs into `main` modifying module code:
* Production will **NEVER change automatically**.
* Production stays pinned to its safe tag until you explicitly go to Issue #18, open the Production PR, review the plan, and merge it yourself.
