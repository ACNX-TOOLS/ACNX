# Playbooks

APBX playbooks for [AME Wizard](https://github.com/Ameliorated-LLC/AME-Wizard). They apply the
ACNX tuning set as a playbook instead of a batch script, for people who prefer a GUI-driven,
scriptable install.

Playbook archives are **not stored in this repository's tree** — each one is ~193 MiB, which is
above GitHub's 100 MiB per-file git limit. They ship in their own release line, tagged
`playbooks-vX.Y.Z`, separate from the batch builds.

## Download

**[Playbooks v1.0.0](https://github.com/ACNX-TOOLS/ACNX/releases/tag/playbooks-v1.0.0)**
· [all releases](https://github.com/ACNX-TOOLS/ACNX/releases)

| File | Size | SHA-256 |
| --- | --- | --- |
| `ACNXPlaybook.apbx` | 202.015.188 B | `df196c396eac18a5545c0ab2e4d212d55ab221d7ac614dbd52d19c4fd494679d` |
| `ReimaginedOS-MOD.apbx` | 202.014.564 B | `dcc5a60cfd1b64310e1b25d5fb84b2fe32761857b5d88aacbca8b8118eb7d223` |

Verify before running:

```powershell
Get-FileHash .\ACNXPlaybook.apbx -Algorithm SHA256
```

## What they are

| Playbook | Based on | Purpose |
| --- | --- | --- |
| `ACNXPlaybook.apbx` | ACNX tuning set | The ACNX service, network and GPU configuration applied through AME Wizard |
| `ReimaginedOS-MOD.apbx` | ReimaginedOS | ReimaginedOS layout and debloat set, modified to keep the network and NVIDIA stack intact |

## Requirements

| Item | Requirement |
| --- | --- |
| OS | Windows 10 22H2 / Windows 11 |
| Tool | [AME Wizard](https://github.com/Ameliorated-LLC/AME-Wizard) |
| Privileges | Administrator |
| Disk | ~1.5 GB free during install |

## Install

```text
1. Download AME Wizard.
2. Run AME Wizard as administrator.
3. Drag the .apbx file into the AME Wizard window (or File -> Open playbook).
4. Read the playbook summary page, then proceed.
5. Reboot when prompted.
```

AME Wizard verifies the playbook signature and applies the steps in order. Do not close the
window while it runs.

## The encryption is normal

Both archives are 7z containers with **encrypted headers**. That is how AME Wizard playbooks are
packaged — AME Wizard holds the key and opens them transparently.

If you try to open one with 7-Zip you will get:

```text
ERROR: Cannot open encrypted archive. Wrong password?
```

That is expected, not corruption, and not a sign of a bad download. Confirm integrity with the
SHA-256 above instead, and open the file with AME Wizard.

## Recovery

Playbooks change services and the OS image. Before running:

```powershell
# 1. Create a restore point
Checkpoint-Computer -Description "Pre-ACNX-playbook" -RestorePointType MODIFY_SETTINGS

# 2. Or snapshot a VM if you are testing
```

If the network or the NVIDIA overlay breaks afterwards, apply the fixer from the batch build that
matches what the playbook changed:

```text
ACNXClick.bat        ->  [1] Wifi Fixer   /   [7] Nvidia Fixer
ACNXHI+OPTIMIZER.bat ->  07 EXTRA -> [3] WIFI FIX / [5] NET+NVIDIA FIX
```

Full steps in [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md).

## Which should I use?

Playbooks and batch scripts are alternatives, not a stack. Pick one:

| You want | Use |
| --- | --- |
| A GUI, rollback-friendly install | a playbook above |
| A portable `.bat` you can read line by line | [the batch builds](../README.md#download) |

Running both in the same install will apply overlapping service changes and make problems
impossible to diagnose.
