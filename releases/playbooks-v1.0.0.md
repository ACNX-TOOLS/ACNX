# ACNX Playbooks — v1.0.0

**Release date:** 2026-10-19
**Tag:** `playbooks-v1.0.0`
**Status:** stable

Release line for the APBX playbooks. They are versioned **separately** from the batch builds:
a playbook release only ever contains playbook archives, and a batch release only ever contains
`.bat` / `.cmd` builds. That way a download link for one never silently changes into the other.

| Release line | Tag pattern | Assets |
| --- | --- | --- |
| Batch builds | `vX.Y.Z` | `ACNX-vX.Y.Z.zip`, `SHA256SUMS.txt` |
| Playbooks | `playbooks-vX.Y.Z` | `*.apbx` |

---

## Downloads

| File | Size | SHA-256 |
| --- | --- | --- |
| `ACNXPlaybook.apbx` | 202.015.188 B | `df196c396eac18a5545c0ab2e4d212d55ab221d7ac614dbd52d19c4fd494679d` |

Verify before running:

```powershell
Get-FileHash .\ACNXPlaybook.apbx -Algorithm SHA256
```

---

## What they are

| Playbook | Based on | Purpose |
| --- | --- | --- |
| `ACNXPlaybook.apbx` | ACNX tuning set | Service, network and GPU configuration applied through AME Wizard |

## Requirements

| Item | Requirement |
| --- | --- |
| OS | Windows 10 22H2 or Windows 11 |
| Tool | [AME Wizard](https://github.com/Ameliorated-LLC/AME-Wizard) |
| Privileges | Administrator |
| Disk | ~1.5 GB free during install |

## Install

```text
1. Run AME Wizard as administrator.
2. Drag the .apbx into the window (or File -> Open playbook).
3. Read the summary page, then proceed.
4. Reboot when prompted.
```

## The password prompt is normal

Both archives are 7z containers with **encrypted headers**. Opening one with 7-Zip gives:

```text
ERROR: Cannot open encrypted archive. Wrong password?
```

That is how AME Wizard playbooks are packaged — AME Wizard holds the key and opens them
transparently. It is not corruption and not a failed download. Verify with the SHA-256 above, then
open the file with AME Wizard.

## Before you run

```powershell
Checkpoint-Computer -Description "Pre-ACNX-playbook" -RestorePointType MODIFY_SETTINGS
```

Playbooks change services and the OS image. A restore point is the fastest way back.

## Recovery

If Wi-Fi, Ethernet or the NVIDIA overlay breaks afterwards, apply the fixer from the batch build:

```text
ACNXClick.bat        ->  [1] Wifi Fixer   /   [7] Nvidia Fixer
ACNXHI+OPTIMIZER.bat ->  07 EXTRA -> [3] WIFI FIX / [5] NET+NVIDIA FIX
```

Then reboot. Full steps in [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md).

## Do not stack

Playbooks and batch builds apply overlapping service changes. Run one or the other. To switch,
apply the matching fixer, reboot, then run the new one.

## Checksums

GitHub prints the `sha256:` digest next to every asset on this page — click it to copy. That is
the same value as the table above, so there is no separate manifest file to download.

The manifest also lives in the repository at [`playbooks/SHA256SUMS.txt`](../playbooks/SHA256SUMS.txt)
if you want to verify from a clone.
