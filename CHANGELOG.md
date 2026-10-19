# Changelog

All notable changes to ACNX are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The full release list, with download tables and checksums, lives in [`releases/`](releases/).

Two release lines are versioned independently:

| Line | Tag | Contents |
| --- | --- | --- |
| Batch builds | `vX.Y.Z` | `ACNX-vX.Y.Z.zip`, `SHA256SUMS.txt` |
| Playbooks | `playbooks-vX.Y.Z` | `*.apbx`, `SHA256SUMS-playbooks.txt` |

---

## [playbooks-1.0.0] - 2026-10-19

First playbook release. Separate line from the batch builds; the batch scripts are unchanged.

### Added

- `ACNXPlaybook.apbx` — ACNX tuning set packaged for AME Wizard.
- `ReimaginedOS-MOD.apbx` — ReimaginedOS layout and debloat, network and NVIDIA stack kept intact.
- `playbooks/README.md` — install steps, checksums, encryption notes and recovery paths.
- `playbooks/SHA256SUMS.txt` — versioned manifest for both archives.

### Notes

- Playbook archives are ~193 MiB each. GitHub's git limit is 100 MiB per file, so they ship as
  release assets and never enter the tree.
- Both archives have encrypted 7z headers. 7-Zip reports `Wrong password?` by design; AME Wizard
  holds the key. Integrity is confirmed by SHA-256, not by opening the archive.

---

## [1.0.0] - 2026-10-19

First public source release. This is the **network-safe** branch: every build below keeps
Wi-Fi, Ethernet, the NVIDIA App and the NVIDIA overlay (Alt+Z) functional.

### Added

- `tools/audit-release.ps1` — byte-level auditor. Fails the build if any active line disables a
  network service, NDIS component, virtual Wi-Fi filter or NVIDIA container.
- `tools/build-release.ps1` — reproducible release packaging with SHA-256 manifest generation.
- GitHub Actions workflow that runs the audit on every push and publishes on tag.
- Recovery documentation for both fixers in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

### Fixed — `ACNXClick.bat` (One-Click)

- Re-enabled 14 network services and 8 NDIS components that the original script had disabled.
- Restored `BFE` to `auto`, `WinHttpAutoProxySvc` and `ClipSVC` to `demand`.
- `EnableActiveProbing` `0` → `1`; `NoActiveProbe` `1` → `0`.
- Restored the NVIDIA tray entry (`StartOnLogin` `0` → `1`).
- Extended `[1] Wifi Fixer` to also restore `dot3svc`, `Eaphost`, `lltdsvc`, `wcncsvc`, `wlpasvc`.
- Added `[7] Nvidia Fixer` to the fixers menu.
- Commented `sc config` lines for `dot3svc`, `Eaphost`, `lltdsvc`, `RmSvc`, `wcncsvc`, `wlpasvc`
  inside the "Disable ALL Services" block, which had been silently killing WPA-Enterprise Wi-Fi,
  802.1X wired authentication and radio control.

### Fixed — `ACNXNUM+OPTIMIZER.cmd` (Platinum)

- `DisableOverlay` `1` → `0`.
- Added a `NETWORK + NVIDIA RESTORE` block that runs automatically before the forced reboot.

### Fixed — `ACNXHI+OPTIMIZER.bat` (High Impact)

- Commented every `sc config` line that disabled an NVIDIA container.
- `NoDaemon` `1` → `0`; `NvTray StartOnLogin` `0` → `1` (two locations).
- `NoActiveProbe` `1` → `0`; `EnableActiveProbing` `0` → `1` (three locations).
- `WinHttpAutoProxySvc` `4` → `3` and `disabled` → `demand` (two locations each).
- `WlanSvc` `demand` → `auto` (two locations); `BFE` and `Dnscache` `demand` → `auto`.
- `lmhosts` `disabled` → `auto` (four locations).
- `LanmanWorkstation` `disabled` → `auto` (two locations).
- `LanmanServer` `disabled` → `demand` (two locations).
- `RasMan`, `RemoteAccess`, `iphlpsvc` `disabled` → `demand`.
- Added `:acnx_fix` routine, wired to `07 EXTRA` → `[5] NET+NVIDIA FIX`, including IPv6 and
  Teredo restoration.

### Known side effects

These are deliberate optimizer changes, not defects, and are documented so users can decide:

- IPv6 is disabled by `ACNXClick.bat` and `ACNXHI+OPTIMIZER.bat` (`DisabledComponents=255` plus a
  bind/unbind of `ms_tcpip6`). IPv4 is unaffected. Both fixers restore it.
- `ACNXClick.bat` and `ACNXHI+OPTIMIZER.bat` set `EnableLUA=0`, which disables the UAC consent
  prompt. `ACNXNUM+OPTIMIZER.cmd` sets `ConsentPromptBehaviorAdmin=0` instead.
- `ACNXNUM+OPTIMIZER.cmd` disables Windows Update services and pauses updates until 2099.
- `ACNXHI+OPTIMIZER.bat` sets `hypervisorlaunchtype off`, `vm No` and `vsmlaunchtype Off`, which
  breaks WSL2, Hyper-V, Docker Desktop and Android emulators. It also sets `nx OptIn`, lowering
  DEP coverage from `OptOut` to `OptIn`.

### Verified

- Zero active disabling lines across all three scripts, checked at byte level.
- CRLF preserved, zero bare LF.
- SHA-256 recorded per file in `SHA256SUMS.txt` on every release.

[1.0.0]: https://github.com/acenkk13/ACNX/releases/tag/v1.0.0
