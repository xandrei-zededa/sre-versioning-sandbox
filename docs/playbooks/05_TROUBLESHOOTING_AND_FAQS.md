# Playbook 05: Troubleshooting CI, Renovate & Release Please

## 1. Issue: "Validate PR Title" Fails in CI

### Error:
`##[error] No release type found in pull request title ...`

### Cause:
The PR title does not comply with Conventional Commits. Release Please cannot parse non-semantic titles.

### Fix:
1. Click **Edit** next to the PR title on GitHub.
2. Rename according to syntax:
   `<type>(<scope>): <description>`
   * Example: `feat(aws-eks): add support for karpenter node role`
   * Example: `fix(irsa-role): fix oidc condition`
3. CI automatically re-runs and turns green within 5 seconds.

---

## 2. Issue: "OpenTofu Format Check" Fails in CI

### Error:
`terraform-modules/parts/.../main.tf`
`OpenTofu exited with code 3`

### Cause:
Unformatted HCL indentation or trailing whitespace.

### Fix:
Run automatic formatter locally:
```bash
tofu fmt -recursive terraform-modules
git commit -am "style: format hcl"
git push
```

---

## 3. Issue: "1 workflow awaiting approval"

### Error:
GitHub Actions shows yellow banner requiring maintainer approval on Renovate PRs.

### Fix:
1. Go to repository **Settings -> Actions -> General**.
2. Under **Fork pull request workflows from outside collaborators**, choose:
   `Require approval for first-time contributors with no prior commits`.
3. Save. Workflows will now run immediately on bot PRs.

---

## 4. Issue: Dependency Dashboard Does Not Show Latest Releases

### Fix:
Self-Hosted Renovate runs automatically on every `push` to `main` and on every PR `closed`.
If an immediate refresh is required:
1. Go to **Actions -> Renovate (Self-Hosted Runner)**.
2. Click **Run workflow** -> select `main`.
3. The dashboard in Issue #18 updates in ~20 seconds.
