<#
.SYNOPSIS
    Live health check for the exact things ACNX guarantees: Wi-Fi, Ethernet and the NVIDIA stack.

.DESCRIPTION
    Run this after an optimizer. It inspects the machine, not the scripts:

      network services, NDIS/WLAN components, NCSI probes, IPv6 binding,
      adapters, connectivity, NVIDIA containers, overlay registry,
      ShadowPlay state and the decoded overlay hotkey.

    Without -Fix it only reports. With -Fix it restores whatever it finds broken and prints each
    change. Exit code 0 means everything on the guaranteed path is healthy.

.PARAMETER Fix
    Apply repairs. Requires an elevated shell.

.PARAMETER TestOverlay
    Send Alt+Z and confirm the overlay window actually opens and closes. Visible on screen for
    about two seconds.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\verify-live.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\verify-live.ps1 -Fix -TestOverlay
#>
[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$TestOverlay
)

$ErrorActionPreference = 'SilentlyContinue'
$script:issues = @()
$script:fixed  = @()

function Add-Issue {
    param([string]$Area, [string]$What, [string]$Repair)
    $script:issues += [pscustomobject]@{ Area = $Area; What = $What; Repair = $Repair }
}

function Invoke-Repair {
    param([string]$Label, [scriptblock]$Action)
    if (-not $Fix) { return }
    try {
        & $Action | Out-Null
        $script:fixed += $Label
        Write-Host "    repaired: $Label" -ForegroundColor Green
    } catch {
        Write-Host "    repair FAILED: $Label - $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Section { param([string]$Text) Write-Host ''; Write-Host "== $Text ==" -ForegroundColor Cyan }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "ACNX live check  |  admin=$isAdmin  fix=$Fix" -ForegroundColor DarkGray
if ($Fix -and -not $isAdmin) {
    Write-Host 'refusing to repair without elevation - rerun as administrator' -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Network services
# ---------------------------------------------------------------------------

Section 'network services'

$serviceRules = @(
    @{ Name='WlanSvc';              Want='auto'   },
    @{ Name='WwanSvc';              Want='auto'   },
    @{ Name='Wcmsvc';               Want='auto'   },
    @{ Name='Netman';               Want='demand' },
    @{ Name='NetSetupSvc';          Want='demand' },
    @{ Name='NlaSvc';               Want='auto'   },
    @{ Name='NcaSvc';               Want='demand' },
    @{ Name='NcbService';           Want='demand' },
    @{ Name='NcdAutoSetup';         Want='demand' },
    @{ Name='Dhcp';                 Want='auto'   },
    @{ Name='Dnscache';             Want='auto'   },
    @{ Name='nsi';                  Want='auto'   },
    @{ Name='netprofm';             Want='demand' },
    @{ Name='BFE';                  Want='auto'   },
    @{ Name='MpsSvc';               Want='auto'   },
    @{ Name='iphlpsvc';             Want='auto'   },
    @{ Name='WinHttpAutoProxySvc';  Want='demand' },
    @{ Name='RasMan';               Want='auto'   },
    @{ Name='RemoteAccess';         Want='demand' },
    @{ Name='dot3svc';              Want='demand' },
    @{ Name='Eaphost';              Want='demand' },
    @{ Name='RmSvc';                Want='demand' },
    @{ Name='lmhosts';              Want='demand' },
    @{ Name='LanmanWorkstation';    Want='auto'   },
    @{ Name='LanmanServer';         Want='demand' },
    @{ Name='wlpasvc';              Want='demand' },
    @{ Name='wcncsvc';              Want='demand' },
    @{ Name='lltdsvc';              Want='demand' }
)

foreach ($r in $serviceRules) {
    $svc = Get-CimInstance Win32_Service -Filter "Name='$($r.Name)'"
    if (-not $svc) {
        Write-Host ("  {0,-24} not installed" -f $r.Name) -ForegroundColor DarkGray
        continue
    }
    $disabled = $svc.StartMode -eq 'Disabled'
    $marker = if ($disabled) { 'DISABLED  <-- breaks Wi-Fi/Ethernet' } else { $svc.StartMode }
    $color  = if ($disabled) { 'Red' } else { 'DarkGray' }
    Write-Host ("  {0,-24} {1,-9} {2}" -f $r.Name, $svc.State, $marker) -ForegroundColor $color
    if ($disabled) {
        Add-Issue 'network' "$($r.Name) is Disabled" "sc config $($r.Name) start= $($r.Want)"
        Invoke-Repair "$($r.Name) -> $($r.Want)" { sc.exe config $r.Name start= $r.Want }
    }
}

# ---------------------------------------------------------------------------
# NDIS / WLAN components
# ---------------------------------------------------------------------------

Section 'NDIS and WLAN components'

foreach ($d in 'NdisCap','NdisVirtualBus','Ndu','vwifibus','vwififlt','vwifimp','wanarp','wanarpv6','ndisuio','NdisWan') {
    $p = "HKLM:\SYSTEM\CurrentControlSet\Services\$d"
    if (-not (Test-Path $p)) { continue }
    $start = (Get-ItemProperty $p).Start
    if ($start -eq 4) {
        Write-Host ("  {0,-18} Start=4  <-- DISABLED" -f $d) -ForegroundColor Red
        Add-Issue 'ndis' "$d has Start=4" "reg add HKLM\SYSTEM\CurrentControlSet\Services\$d /v Start /t REG_DWORD /d 3 /f"
        Invoke-Repair "$d Start=3" { reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\$d" /v Start /t REG_DWORD /d 3 /f }
    } else {
        Write-Host ("  {0,-18} Start={1}" -f $d, $start) -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# Connectivity probe / IPv6
# ---------------------------------------------------------------------------

Section 'connectivity probe and IPv6'

$probe = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet').EnableActiveProbing
Write-Host ("  EnableActiveProbing       = {0}" -f $probe)
if ($probe -ne 1) {
    Add-Issue 'ncsi' 'EnableActiveProbing is not 1' 'set it to 1'
    Invoke-Repair 'EnableActiveProbing=1' { reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet' /v EnableActiveProbing /t REG_DWORD /d 1 /f }
}

$nap = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator').NoActiveProbe
Write-Host ("  NoActiveProbe             = {0}" -f $(if ($null -eq $nap) { '(absent, good)' } else { $nap }))
if ($nap -eq 1) {
    Add-Issue 'ncsi' 'NoActiveProbe policy is 1' 'set it to 0'
    Invoke-Repair 'NoActiveProbe=0' { reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator' /v NoActiveProbe /t REG_DWORD /d 0 /f }
}

$dc = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters').DisabledComponents
Write-Host ("  DisabledComponents        = {0}" -f $(if ($null -eq $dc) { '(absent, IPv6 on)' } else { $dc }))
if ($null -ne $dc -and $dc -ne 0) {
    Add-Issue 'ipv6' "IPv6 disabled (DisabledComponents=$dc)" 'set to 0 and re-enable the binding'
    Invoke-Repair 'IPv6 re-enabled' {
        reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' /v DisabledComponents /t REG_DWORD /d 0 /f
        Enable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip6
        netsh interface teredo set state default
    }
}

foreach ($b in Get-NetAdapterBinding -ComponentID ms_tcpip6) {
    if (-not $b.Enabled) {
        Add-Issue 'ipv6' "IPv6 binding disabled on $($b.Name)" "Enable-NetAdapterBinding -Name '$($b.Name)' -ComponentID ms_tcpip6"
        Invoke-Repair "IPv6 binding on $($b.Name)" { Enable-NetAdapterBinding -Name $b.Name -ComponentID ms_tcpip6 }
    }
}

# ---------------------------------------------------------------------------
# Adapters and connectivity
# ---------------------------------------------------------------------------

Section 'adapters'

foreach ($a in Get-NetAdapter | Where-Object { $_.InterfaceDescription -notmatch 'Bluetooth' }) {
    $color = if ($a.Status -eq 'Up') { 'Green' } else { 'Yellow' }
    Write-Host ("  {0,-12} {1,-13} {2,-10} {3}" -f $a.Name, $a.Status, "$($a.LinkSpeed)", $a.InterfaceDescription) -ForegroundColor $color
    $if4 = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
           Where-Object { $_.IPAddress -notlike '169.254.*' }
    if ($a.Status -eq 'Up' -and -not $if4) {
        Add-Issue 'adapter' "$($a.Name) is Up but has no DHCP address" 'ipconfig /renew'
        Invoke-Repair "renew lease on $($a.Name)" { ipconfig.exe /renew }
    }
}

Section 'connectivity'

$ping = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet
Write-Host ("  ping 8.8.8.8              = {0}" -f $ping) -ForegroundColor $(if ($ping) { 'Green' } else { 'Red' })
if (-not $ping) { Add-Issue 'internet' 'no ICMP reply from 8.8.8.8' 'check gateway and cable/SSID' }

$dns = $null
try { $dns = (Resolve-DnsName 'www.google.com' -ErrorAction Stop | Where-Object { $_.IPAddress }).IPAddress | Select-Object -First 1 } catch {}
Write-Host ("  DNS www.google.com        = {0}" -f $(if ($dns) { $dns } else { 'FAIL' })) -ForegroundColor $(if ($dns) { 'Green' } else { 'Red' })
if (-not $dns) { Add-Issue 'internet' 'DNS resolution failed' 'ipconfig /flushdns ; check DNS server' }

$http = $null
try { $http = (Invoke-WebRequest 'https://www.google.com' -UseBasicParsing -TimeoutSec 10).StatusCode } catch {}
Write-Host ("  HTTPS google.com          = {0}" -f $(if ($http) { $http } else { 'FAIL' })) -ForegroundColor $(if ($http) { 'Green' } else { 'Red' })
if ($http -ne 200) { Add-Issue 'internet' 'HTTPS request failed' 'check firewall and proxy' }

# ---------------------------------------------------------------------------
# NVIDIA
# ---------------------------------------------------------------------------

Section 'NVIDIA containers'

foreach ($n in 'NvContainerLocalSystem','NVDisplay.ContainerLocalSystem') {
    $svc = Get-CimInstance Win32_Service -Filter "Name='$n'"
    if (-not $svc) {
        Write-Host ("  {0,-32} not installed" -f $n) -ForegroundColor Yellow
        Add-Issue 'nvidia' "$n is not installed" 'reinstall NVIDIA App'
        continue
    }
    $bad = ($svc.StartMode -eq 'Disabled') -or ($svc.State -ne 'Running')
    Write-Host ("  {0,-32} {1,-9} {2}" -f $n, $svc.State, $svc.StartMode) -ForegroundColor $(if ($bad) { 'Red' } else { 'Green' })
    if ($bad) {
        Add-Issue 'nvidia' "$n is $($svc.State)/$($svc.StartMode)" "sc config $n start= auto ; net start $n"
        Invoke-Repair "$n -> auto and started" {
            sc.exe config $n start= auto
            sc.exe start $n
        }
    }
}

Section 'overlay and ShadowPlay'

$nvTweak = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak'
$disableOverlay = (Get-ItemProperty $nvTweak).DisableOverlay
Write-Host ("  DisableOverlay            = {0}" -f $(if ($null -eq $disableOverlay) { '(absent, overlay on)' } else { $disableOverlay })) -ForegroundColor $(if ($disableOverlay -eq 1) { 'Red' } else { 'Green' })
if ($disableOverlay -eq 1) {
    Add-Issue 'nvidia' 'overlay disabled in registry (DisableOverlay=1)' 'reg add .../NVTweak /v DisableOverlay /d 0'
    Invoke-Repair 'DisableOverlay=0' { reg.exe add 'HKLM\SOFTWARE\NVIDIA Corporation\Global\NVTweak' /v DisableOverlay /t REG_DWORD /d 0 /f }
}

$sp = 'HKCU:\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS'
$caps = Get-ItemProperty $sp
function Get-Dword { param($bytes) if ($bytes -is [byte[]] -and $bytes.Length -ge 4) { [BitConverter]::ToUInt32($bytes, 0) } else { $null } }

$enabled = Get-Dword $caps.IsShadowPlayEnabled
Write-Host ("  IsShadowPlayEnabled       = {0}" -f $enabled) -ForegroundColor $(if ($enabled -eq 1) { 'Green' } else { 'Red' })
if ($enabled -ne 1) { Add-Issue 'nvidia' 'ShadowPlay disabled in registry' 'toggle Instant Replay in the overlay (Alt+Z -> gear)' }

$hkCount = Get-Dword $caps.GFEOverlayHKeyV2Count
$hk0 = Get-Dword $caps.GFEOverlayHKeyV20
$hk1 = Get-Dword $caps.GFEOverlayHKeyV21
if ($hkCount -eq 2) {
    $mod = switch ($hk0) { 0x12 { 'Alt' } 0x11 { 'Ctrl' } 0x10 { 'Shift' } default { "0x$($hk0.ToString('X2'))" } }
    $key = if ($hk1 -ge 0x41 -and $hk1 -le 0x5A) { [char]$hk1 } else { "0x$($hk1.ToString('X2'))" }
    Write-Host ("  overlay hotkey            = {0}+{1}" -f $mod, $key) -ForegroundColor Green
} else {
    Write-Host '  overlay hotkey            = (not configured the standard way)'
}

$overlayProcs = @(Get-Process 'NVIDIA Overlay' -ErrorAction SilentlyContinue)
Write-Host ("  NVIDIA Overlay processes  = {0}" -f $overlayProcs.Count) -ForegroundColor $(if ($overlayProcs.Count) { 'Green' } else { 'Red' })
if (-not $overlayProcs.Count) { Add-Issue 'nvidia' 'NVIDIA Overlay is not running' 'restart NvContainerLocalSystem, then launch NVIDIA App' }

$nvApp = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
         Where-Object { $_.DisplayName -match '^NVIDIA App' } | Select-Object -First 1
if ($nvApp) { Write-Host ("  NVIDIA App                = {0}" -f $nvApp.DisplayVersion) -ForegroundColor Green }
else        { Write-Host '  NVIDIA App                = not found' -ForegroundColor Yellow; Add-Issue 'nvidia' 'NVIDIA App not installed' 'install from the Microsoft Store' }

# ---------------------------------------------------------------------------
# Optional live overlay toggle
# ---------------------------------------------------------------------------

if ($TestOverlay) {
    Section 'live Alt+Z test'
    $code = @'
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class AcnxOv {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte sc, uint f, UIntPtr e);
  delegate bool EnumProc(IntPtr h, IntPtr p);
  public static int Visible() { int n=0; EnumWindows((h,x)=>{ var sb=new StringBuilder(256); GetClassName(h,sb,256);
      if (sb.ToString().Contains("CEF") && IsWindowVisible(h)) n++; return true; }, IntPtr.Zero); return n; }
  public static void AltZ() { const byte M=0x12,Z=0x5A;
      keybd_event(M,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(80);
      keybd_event(Z,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(80);
      keybd_event(Z,0,2,UIntPtr.Zero); System.Threading.Thread.Sleep(40);
      keybd_event(M,0,2,UIntPtr.Zero); }
}
'@
    if (-not ('AcnxOv' -as [type])) { Add-Type -TypeDefinition $code -Language CSharp }

    $before = [AcnxOv]::Visible()
    [AcnxOv]::AltZ(); Start-Sleep -Milliseconds 2500
    $opened = [AcnxOv]::Visible()
    [AcnxOv]::AltZ(); Start-Sleep -Milliseconds 1500
    $closed = [AcnxOv]::Visible()

    Write-Host ("  visible CEF windows: before={0} opened={1} closed={2}" -f $before, $opened, $closed)
    if ($opened -gt $before -and $closed -le $before) {
        Write-Host '  Alt+Z opens and closes the overlay' -ForegroundColor Green
    } else {
        Write-Host '  Alt+Z did not toggle the overlay' -ForegroundColor Red
        Add-Issue 'nvidia' 'Alt+Z did not toggle the overlay during the live test' 'check the hotkey in NVIDIA App settings'
    }
}

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------

Write-Host ''
if ($script:issues.Count -eq 0) {
    Write-Host 'LIVE CHECK PASS - Wi-Fi, Ethernet and NVIDIA are healthy' -ForegroundColor Green
    exit 0
}

Write-Host ("LIVE CHECK - {0} issue(s)" -f $script:issues.Count) -ForegroundColor $(if ($Fix) { 'Yellow' } else { 'Red' })
foreach ($i in $script:issues) {
    Write-Host ("  [{0}] {1}" -f $i.Area, $i.What) -ForegroundColor Yellow
    Write-Host ("         repair: {0}" -f $i.Repair) -ForegroundColor DarkYellow
}
if (-not $Fix) {
    Write-Host ''
    Write-Host 'rerun with -Fix to apply the repairs above' -ForegroundColor Cyan
    exit 1
}
Write-Host ''
if ($script:fixed.Count) {
    Write-Host ("applied {0} repair(s): {1}" -f $script:fixed.Count, ($script:fixed -join ', ')) -ForegroundColor Green
    Write-Host 'reboot, then run this check again without -Fix' -ForegroundColor Cyan
} else {
    Write-Host 'nothing was repaired - the issues above need manual attention' -ForegroundColor Red
}
exit 1
