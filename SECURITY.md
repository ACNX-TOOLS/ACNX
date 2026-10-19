# Security Policy

## Scope

ACNX ships batch files that change Windows services, registry keys and boot configuration with
administrator privileges. That is the entire product. The security surface is therefore:

- whether a script does something it does not document;
- whether a released binary matches the published checksum;
- whether the recovery paths actually restore the original state.

## Reporting

Do not open a public issue for any of the following. Email the maintainer instead, or use
GitHub's private vulnerability reporting on this repository:

- a script contains code that is not described in the release notes;
- a published artifact does not match `SHA256SUMS.txt`;
- a fixer fails to restore a service or registry value it claims to restore;
- a build disables something the audit is supposed to block.

Include the build name, the release tag, the checksum you observed, and the exact lines.

**Maintainer:** [@acenkk13](https://github.com/acenkk13)

## What is not a vulnerability

- IPv6 being disabled by `ACNXClick.bat` and `ACNXHI+OPTIMIZER.bat` — documented in
  `CHANGELOG.md` under *Known side effects*.
- UAC consent being disabled — documented, and restorable.
- Windows Update being paused by `ACNXNUM+OPTIMIZER.cmd` — documented, and restorable.
- `hypervisorlaunchtype off` breaking WSL2/Hyper-V — documented, and restorable.
- Windows Defender or Windows Firewall being circumvented — they are not touched by any build.

These are deliberate, reversible optimizer changes, not defects. Disagreeing with them is a
feature request, not a security report.

## Verification

Every release publishes a SHA-256 manifest. Verify before running:

```powershell
Get-FileHash .\ACNX-v1.0.0.zip -Algorithm SHA256
```

A release whose checksum you cannot verify should be treated as untrusted, even if it came from
this repository's release page.

## Supported versions

| Version | Supported |
| --- | :---: |
| 1.x | yes |

Only the latest release in the current major version receives fixes.
