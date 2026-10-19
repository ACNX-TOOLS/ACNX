# Install

ACNX is a set of portable batch scripts. There is no installer and nothing is added to
`Program Files`.

## Requirements

| Item | Requirement |
| --- | --- |
| OS | Windows 10 22H2 or Windows 11 |
| Shell | `cmd.exe` (the scripts are `.bat` / `.cmd`) |
| Privileges | **Administrator** — every step that matters uses `sc config`, `reg add`, `bcdedit` |
| Free disk | ~5 MB for the scripts and their backups |

PowerShell is only needed for the optional helpers in `tools/`.

## Download

1. Open the [Releases](https://github.com/acenkk13/ACNX/releases) page.
2. Download `ACNX-vX.Y.Z.zip` (or a single script if you only want one build).
3. Extract to a folder you control, for example `D:\ACNX`.

Do not run the scripts directly from inside the ZIP viewer — `cmd.exe` cannot resolve relative
paths there and the menu art renders as garbage.

## Verify

```powershell
Get-FileHash .\ACNX-v1.0.0.zip -Algorithm SHA256
```

Compare with `SHA256SUMS.txt` from the same release. If it does not match, delete the archive.

## Run

```text
1. Right-click the script.
2. "Run as administrator".
3. Accept the UAC prompt.
4. Choose a profile from the menu.
5. Reboot when it finishes.
```

If the window closes instantly, you double-clicked instead of elevating. Nothing was changed;
`sc config` fails silently without elevation.

## After the first reboot

Check these three things before doing anything else:

```powershell
# 1. Wi-Fi / Ethernet
Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, LinkSpeed

# 2. NVIDIA containers
Get-Service NvContainerLocalSystem, NVDisplay.ContainerLocalSystem | Select-Object Name, Status, StartType

# 3. Overlay registry
Get-ItemProperty 'HKLM:\SOFTWARE\NVIDIA Corporation\NVTweak' -Name DisableOverlay -ErrorAction SilentlyContinue
```

Then press **Alt+Z**. If the overlay opens, the run succeeded.

## Uninstall

There is no uninstaller, but every build keeps a backup:

```text
%SystemDrive%\ACNX_Backup\
```

The scripts also export the service registry hive before changing it:

```text
%SystemDrive%\ACNX_Backup\Services\Services.reg
```

To roll back manually, use the fixer menu of the build you ran (see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md)) and reboot. For a full reset, restore your own system
restore point or the `Services.reg` export.

## Running several builds

Do not. Run one build, reboot, and test. If you want to switch, revert with the current build's
fixer first, reboot, then run the next one.
