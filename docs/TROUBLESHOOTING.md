# Troubleshooting

Every problem below is recoverable. Do not reinstall Windows.

## Fastest path: run the live check

```powershell
# report only
powershell -ExecutionPolicy Bypass -File tools\verify-live.ps1

# repair anything broken, then toggle Alt+Z to prove the overlay works
powershell -ExecutionPolicy Bypass -File tools\verify-live.ps1 -Fix -TestOverlay
```

It prints each finding with the exact repair command, and exits non-zero while anything on the
Wi-Fi / Ethernet / NVIDIA path is broken. Use the manual steps below when you want to see exactly
what is being changed.

## First: run the fixer, then reboot

| Build you ran | Fixer path |
| --- | --- |
| `ACNXClick.bat` | `[1] Wifi Fixer` for network, `[7] Nvidia Fixer` for the overlay |
| `ACNXHI+OPTIMIZER.bat` | `07 EXTRA` → `[3] WIFI FIX`, and `07 EXTRA` → `[5] NET+NVIDIA FIX` |
| `ACNXNUM+OPTIMIZER.cmd` | runs `NETWORK + NVIDIA RESTORE` automatically before its reboot; re-run the script if you skipped it |

Run the fixer **as administrator**, then reboot. Most reports resolve here.

---

## Wi-Fi does not appear / no networks listed

The WLAN stack is down. Check in this order:

```powershell
Get-Service WlanSvc, Wcmsvc, Netman, NlaSvc, netprofm, nsi, Dhcp | Select-Object Name, Status, StartType
```

If any of them are `Disabled`:

```powershell
sc config WlanSvc start= auto
sc config Wcmsvc start= auto
sc config Netman start= demand
sc config NlaSvc start= auto
sc config netprofm start= auto
sc config nsi start= auto
sc config Dhcp start= auto
```

Also confirm the WLAN driver is not disabled:

```powershell
Get-PnpDevice -Class Net | Where-Object InstanceId -like '*SWD\WLAN*' | Select-Object FriendlyName, Status
```

Reboot after.

## Wi-Fi connects but no internet

DNS or the connectivity probe. Check:

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4
reg query "HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet" /v EnableActiveProbing
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator" /v NoActiveProbe
```

Expected: `EnableActiveProbing = 1` and no `NoActiveProbe` value (or `0`). If wrong:

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet" /v EnableActiveProbing /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator" /v NoActiveProbe /t REG_DWORD /d 0 /f
ipconfig /flushdns
```

## Ethernet dead, Wi-Fi fine

```powershell
Get-NetAdapterBinding -ComponentID ms_tcpip, ms_tcpip6
Get-Service dot3svc, Eaphost, Dhcp, BFE
```

Re-enable the bindings and services:

```powershell
Enable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip
sc config dot3svc start= demand
sc config Eaphost start= demand
sc config BFE start= auto
```

## WPA-Enterprise / campus Wi-Fi fails (802.1X)

`Eaphost` or `dot3svc` was disabled:

```powershell
sc config Eaphost start= demand
sc config dot3svc start= demand
sc config RmSvc start= demand
```

## NVIDIA App will not open / Alt+Z does nothing

Check both containers and the overlay flag:

```powershell
Get-Service NvContainerLocalSystem, NVDisplay.ContainerLocalSystem | Select-Object Name, Status, StartType
reg query "HKLM\SOFTWARE\NVIDIA Corporation\NVTweak" /v DisableOverlay
```

Repair:

```powershell
sc config NvContainerLocalSystem start= auto
sc config NVDisplay.ContainerLocalSystem start= auto
sc start  NvContainerLocalSystem
sc start  NVDisplay.ContainerLocalSystem
reg add "HKLM\SOFTWARE\NVIDIA Corporation\NVTweak" /v DisableOverlay /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\NvTray" /v StartOnLogin /t REG_DWORD /d 1 /f
```

Then reboot. If Alt+Z still does nothing, reinstall NVIDIA App from the Microsoft Store; the
overlay is delivered by the App, not by the display driver.

## Alt+Z opens but the overlay is empty / no Instant Replay

Instant Replay is a separate setting. Toggle it from the overlay (`Alt+Z` → gear → Instant
Replay), or from the App's settings. Nothing in ACNX deletes recordings.

## Windows Update refuses to check

Only `ACNXNUM+OPTIMIZER.cmd` disables Windows Update. Undo:

```powershell
sc config wuauserv start= demand
sc config UsoSvc start= demand
sc config WaaSMedicSvc start= demand
sc config bits start= demand
reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesExpiryTime /f
reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesStartTime /f
reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesRequested /f
```

Then Settings → Windows Update → Check for updates.

## WSL2 / Hyper-V / Docker / Android emulator stopped working

`ACNXHI+OPTIMIZER.bat` sets `hypervisorlaunchtype off`. Undo:

```powershell
bcdedit /set hypervisorlaunchtype auto
bcdedit /set vm Yes
bcdedit /deletevalue vsmlaunchtype
bcdedit /set nx OptOut
```

Reboot. Reinstall or re-enable the Windows features afterwards if the emulator still complains.

## UAC prompts no longer appear

`ACNXClick.bat` and `ACNXHI+OPTIMIZER.bat` set `EnableLUA=0`; `ACNXNUM+OPTIMIZER.cmd` sets
`ConsentPromptBehaviorAdmin=0`. Restore:

```powershell
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 5 /f
```

Reboot.

## Nothing helps

1. Restore the `Services.reg` export from `%SystemDrive%\ACNX_Backup\Services\`.
2. Restore your own system restore point.
3. Open an issue with the [bug report template](../.github/ISSUE_TEMPLATE/bug_report.yml) —
   include which build you ran, and the output of:

```powershell
Get-Service WlanSvc, Netman, Dhcp, Dnscache, BFE, NvContainerLocalSystem, NVDisplay.ContainerLocalSystem |
  Select-Object Name, Status, StartType | Format-Table -AutoSize
```
