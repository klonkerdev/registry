# Registry branch protection

The `main` branch is protected by the repository-level GitHub rules, not by a
workflow file alone. The checked-in `.github/CODEOWNERS` file assigns review
ownership, while `.github/workflows/validate.yml` provides the required
`validate` check for every pull request and push.

Pull-request validation uses only the committed public key and detached
signature; private repository secrets are never exposed to pull-request code.
On a trusted push to protected `main`, the same job writes the
`PRIMARY_KEY_2026` repository secret to a temporary runner file, rebuilds the
distribution with that key, and requires the result to match the reviewed
committed `dist/` tree byte-for-byte. The temporary key file is removed even
if the build fails.

An administrator can apply or repair the rule reproducibly:

```powershell
.\eng\protect-main.ps1
```

The rule requires:

- the generic `validate` job to pass on an up-to-date branch;
- one approving code-owner review and approval of the latest push;
- resolved review conversations;
- linear history;
- protection for administrators;
- no force pushes or branch deletion.

The script changes GitHub repository state and therefore requires an
authenticated `gh` session with repository administration permission.
