# Contributing

Thanks for looking. ACNX is a small project with a narrow rule set, so the fastest way in is a
bug report with evidence.

## Ground rules

1. **Never delete a recovery path.** Every destructive change needs a line in the matching fixer.
2. **The audit must stay green.** `tools/audit-release.ps1` blocks any active line that disables
   a network service, NDIS component, virtual Wi-Fi filter or NVIDIA container. Do not weaken the
   auditor to make a change pass.
3. **Byte fidelity matters.** The scripts contain CP437/CP1251 box art and must keep CRLF.
   Edit them with an editor that preserves both, never with something that normalizes line
   endings.
4. **One build, one concern.** If a change belongs to the GPU stack, it does not belong in the
   network block.

## Reporting a bug

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml). Include:

- build name and release tag (`ACNXHI+OPTIMIZER.bat`, `v1.0.0`);
- what you expected, what happened;
- the output of the collection command in
  [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#nothing-helps);
- whether the fixer changed anything.

Redact serial numbers and IP addresses.

## Suggesting a service change

Open a feature request with:

| Field | Value |
| --- | --- |
| Service or key | e.g. `SysMain` |
| Current start type | e.g. `auto` |
| Proposed start type | e.g. `demand` |
| What breaks | e.g. nothing observed on 3 machines |
| What improves | e.g. 340 MB less RAM after boot |

"I saw it in another optimizer" is not a reason. State the measured effect.

## Changing a script

```text
1. Edit src/<build>
2. Run: pwsh -File tools/audit-release.ps1
3. Confirm: 0 findings, CRLF preserved, bare LF = 0
4. Update CHANGELOG.md and releases/<next version>.md
5. Bump VERSION
6. Commit as: fix(click): restore Eaphost for WPA-Enterprise
```

## Commit style

Conventional commits, scoped by build:

```text
fix(hi): keep NvContainerLocalSystem on auto
fix(num): add network restore before reboot
feat(click): add [7] Nvidia Fixer
docs(readme): document SHA-256 verification
audit: catch SC_DISABLED batch loops
```

## Releasing

Maintainer only:

```powershell
# 1. bump VERSION and add releases/vX.Y.Z.md
pwsh -File tools/build-release.ps1
git add .
git commit -m "chore(release): vX.Y.Z"
git tag vX.Y.Z
git push origin main --tags
```

The `release` workflow reruns the audit, builds the archive, attaches `SHA256SUMS.txt` and
publishes the GitHub release.

## Code of conduct

Be specific, be technical, be kind. Bugs are not personal. Nobody is required to accept a patch.
