<div align="center">

# ACNX

**Windows optimization toolkit for gaming and low-latency desktops.**
Every profile is verified to keep **Wi-Fi**, **Ethernet**, **NVIDIA App** and the **NVIDIA overlay (Alt+Z)** working.

[![Latest release](https://img.shields.io/github/v/release/acenkk13/ACNX?style=for-the-badge&label=release)](https://github.com/acenkk13/ACNX/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/acenkk13/ACNX/total?style=for-the-badge)](https://github.com/acenkk13/ACNX/releases)
[![License](https://img.shields.io/github/license/acenkk13/ACNX?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6?style=for-the-badge)](docs/INSTALL.md)

</div>

---

## What this is

ACNX is a set of batch optimizers for Windows 10 and 11. It tunes services, the network stack,
the GPU stack, the storage stack and the scheduler, then exposes **fixers** so every change can be
rolled back without a clean install.

The current build is the **network-safe** branch. Earlier optimizer scripts from the same family
disabled `WlanSvc`, the NDIS upper filters and the NVIDIA containers, which killed Wi-Fi and the
overlay. Every one of those lines is neutralized here and covered by an automated audit that runs
on each release.

## Download

Grab the build you want from the [**Releases**](https://github.com/acenkk13/ACNX/releases) page.

| Build | File | Size | Focus |
| --- | --- | --- | --- |
| **One-Click** | `ACNXClick.bat` | 275 KB | Interactive menu, broadest service and privacy cleanup, ships both fixers |
| **Platinum** | `ACNXNUM+OPTIMIZER.cmd` | 177 KB | Fully automatic, ends with an automatic reboot, includes a network restore block |
| **High Impact** | `ACNXHI+OPTIMIZER.bat` | 748 KB | Largest tweak set, manual reboot, `07 EXTRA` holds `WIFI FIX` and `NET+NVIDIA FIX` |

All three are plain batch files. No installer, no service, no background process.

### Playbooks

If you prefer a GUI-driven install, the same tuning set ships as APBX playbooks for
[AME Wizard](https://github.com/Ameliorated-LLC/AME-Wizard):

| Playbook | Size | Based on |
| --- | --- | --- |
| `ACNXPlaybook.apbx` | 193 MiB | ACNX tuning set |

They live in their own release line —
[**Playbooks v1.0.0**](https://github.com/ACNX-TOOLS/ACNX/releases/tag/playbooks-v1.0.0) — rather
than in this repository, because each archive is above GitHub's 100 MiB per-file git limit.
Playbook releases use the tag `playbooks-vX.Y.Z` and never mix with batch builds.
Details, checksums and recovery steps: [playbooks/README.md](playbooks/README.md).

Playbooks and batch scripts are alternatives — run one or the other, not both.

## Verify before you run

Every release ships `SHA256SUMS.txt`. Check the file you downloaded:

```powershell
Get-FileHash .\ACNXClick.bat -Algorithm SHA256
```

Compare against the matching line in `SHA256SUMS.txt`. If it does not match, do not run it.

## Quick start

```text
1. Extract the release archive.
2. Right-click the .bat / .cmd file  ->  Run as administrator.
3. Pick a profile from the menu.
4. Reboot.
5. Test Wi-Fi/Ethernet and press Alt+Z.
```

Full instructions, including the exact privileges each step needs, are in [docs/INSTALL.md](docs/INSTALL.md).

## Guarantees

These are enforced by `tools/audit-release.ps1` and blocked in CI:

- No active line disables a network service (`WlanSvc`, `Netman`, `Dhcp`, `Dnscache`, `nsi`, `netprofm`, `NcaSvc`, `NcbService`, `NcdAutoSetup`, `NetSetupSvc`, `RasMan`, `RemoteAccess`, `WinHttpAutoProxySvc`, `iphlpsvc`, `BFE`, `dot3svc`, `Eaphost`, `RmSvc`, and more).
- No NDIS component, WLAN driver or virtual Wi-Fi filter is set to `Start=4`.
- No NVIDIA container is disabled; `NvContainerLocalSystem` and `NVDisplay.ContainerLocalSystem` are always left on `auto`.
- No registry key re-enables `NoActiveProbe`, `NoDaemon` or a disabled overlay.
- CRLF line endings preserved, so box art and non-ASCII menu text never break.

## Recovery

Something broke? Do not reinstall Windows.

```text
ACNXClick.bat        ->  [1] Wifi Fixer      /  [7] Nvidia Fixer
ACNXHI+OPTIMIZER.bat ->  07 EXTRA  ->  [3] WIFI FIX  /  [5] NET+NVIDIA FIX
ACNXNUM+OPTIMIZER.cmd->  network restore block runs automatically before reboot
```

Then reboot. Details in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Repository layout

```text
src/                     the three optimizer scripts
playbooks/               APBX playbook notes, checksums and install guide
tools/                   build + audit automation
releases/                one markdown file per release (release list)
docs/                    install, troubleshooting, network/NVIDIA notes
.github/workflows/       CI: audit every push, publish on tag
```

## Contributing

Bug reports, service-list corrections and audit rules are welcome. Read
[CONTRIBUTING.md](CONTRIBUTING.md) first.

Security issues: [SECURITY.md](SECURITY.md), not a public issue.

## Maintainer

**[@acenkk13](https://github.com/acenkk13)** — author and maintainer.

## License

[MIT](LICENSE). Run it on hardware you own. Batch files that change services and boot
configuration are not reversible with a single click, so keep the backups the scripts create
(`%SystemDrive%\ACNX_Backup`) and your own restore point.
