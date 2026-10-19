<#
.SYNOPSIS
    Byte-level audit for the ACNX optimizer scripts.

.DESCRIPTION
    Reads every .bat/.cmd under -Path as Latin-1 (1 char == 1 byte) so CP437/CP1251 box art and
    CRLF survive untouched, then classifies each active line.

    Two tiers:

      BLOCK  Fails the build. Disabling any of these breaks Wi-Fi, Ethernet or the NVIDIA overlay,
             which this project guarantees to keep working.

      WARN   Reported but does not fail. Disabling these is a deliberate optimizer choice; it only
             affects optional paths (IPsec/L2TP/SSTP VPN, Internet Connection Sharing, HomeGroup,
             NVIDIA telemetry) and is documented in CHANGELOG.md.

    Read-only. Nothing is written.

.PARAMETER Path
    Directory holding the scripts. Defaults to ..\src relative to this file.

.PARAMETER Quiet
    Only print the final verdict.

.PARAMETER Strict
    Treat WARN findings as failures. Use this before tagging a release if you intend to ship a
    build with zero VPN regressions.

.EXAMPLE
    pwsh -File tools/audit-release.ps1

.EXAMPLE
    pwsh -File tools/audit-release.ps1 -Path 'C:\Users\me\Documents\tes' -Strict
#>
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$Quiet,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$enc = [Text.Encoding]::GetEncoding(28591)

if (-not $Path) { $Path = Join-Path $PSScriptRoot '..\src' }
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "audit: path not found: $Path" -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Tier 1 - BLOCK: the guaranteed path
# ---------------------------------------------------------------------------

$BlockNetServices = @(
    'WlanSvc',            # WLAN AutoConfig
    'WwanSvc',            # WWAN AutoConfig
    'Wcmsvc',             # Connection Manager
    'Netman',             # Network Connections
    'NetSetupSvc',        # Network Setup Service
    'NlaSvc',             # Network Location Awareness
    'NcaSvc',             # Network Connectivity Assistant
    'NcbService',         # Network Connection Broker
    'NcdAutoSetup',       # Network Connected Devices Auto-Setup
    'Dhcp',               # DHCP Client
    'Dnscache',           # DNS Client
    'nsi',                # Network Store Interface
    'netprofm',           # Network List Service
    'BFE',                # Base Filtering Engine
    'MpsSvc',             # Windows Firewall
    'iphlpsvc',           # IP Helper
    'Ndu',                # Windows Network Data Usage
    'WinHttpAutoProxySvc',# WinHTTP Web Proxy Auto-Discovery
    'RasMan',             # Remote Access Connection Manager
    'dot3svc',            # Wired AutoConfig (802.1X wired)
    'Eaphost',            # Extensible Authentication Protocol (WPA-Enterprise)
    'RmSvc',              # Radio Management
    'lmhosts',            # TCP/IP NetBIOS Helper
    'LanmanWorkstation',  # Workstation (SMB)
    'wlpasvc',            # WLAN policy helper
    'wcncsvc',            # Windows Connect Now
    'lltdsvc'             # Link-Layer Topology Discovery
) | Select-Object -Unique

$BlockNvServices = @(
    'NvContainerLocalSystem',        # NVIDIA LocalSystem Container - required by the overlay
    'NVDisplay.ContainerLocalSystem' # NVIDIA Display Container - required by NVIDIA App
) | Select-Object -Unique

# ---------------------------------------------------------------------------
# Tier 2 - WARN: optional paths and telemetry
# ---------------------------------------------------------------------------

$WarnNetServices = @(
    'IKEEXT',        # IPsec / L2TP keying modules
    'PolicyAgent',   # IPsec Policy Agent
    'SstpSvc',       # SSTP VPN
    'SharedAccess',  # Internet Connection Sharing
    'RemoteAccess',  # Routing and Remote Access
    'p2psvc',        # Peer Name Resolution Protocol
    'p2pimsvc',
    'PNRPsvc',
    'PNRPAutoReg'
) | Select-Object -Unique

$WarnNvServices = @(
    'NvTelemetryContainer',
    'NvContainerUserSvc',
    'NvLst'
) | Select-Object -Unique

$NdisComponents = @(
    'NdisCap','NdisVirtualBus','Ndu','vwifibus','vwififlt','vwifimp',
    'wanarp','wanarpv6','ndisuio','NdisWan'
) | Select-Object -Unique

function ConvertTo-Alternation {
    param([string[]]$Values)
    ($Values | ForEach-Object { [regex]::Escape($_) }) -join '|'
}

$svc = 'sc(\.exe)?\s+config\s+"?(?:{0})"?\s+start\s*=\s*disabled'

$Rules = @(
    @{ Id='NET-SVC';  Sev='BLOCK'; Desc='network service set to disabled'
       Pattern=($svc -f (ConvertTo-Alternation $BlockNetServices)) },
    @{ Id='NV-SVC';   Sev='BLOCK'; Desc='NVIDIA container set to disabled'
       Pattern=($svc -f (ConvertTo-Alternation $BlockNvServices)) },
    @{ Id='NET-WARN'; Sev='WARN';  Desc='optional network service disabled (VPN / ICS / P2P)'
       Pattern=($svc -f (ConvertTo-Alternation $WarnNetServices)) },
    @{ Id='NV-WARN';  Sev='WARN';  Desc='NVIDIA telemetry or optional container disabled'
       Pattern=($svc -f (ConvertTo-Alternation $WarnNvServices)) },
    @{ Id='NDIS-DRV'; Sev='BLOCK'; Desc='NDIS or WLAN component forced to Start=4'
       Pattern=('Services\\(?:{0})"?\s*/v\s*"?Start"?\s*/t\s*REG_DWORD\s*/d\s*"?4\b' -f (ConvertTo-Alternation $NdisComponents)) },
    @{ Id='NCSI';     Sev='BLOCK'; Desc='connectivity probe disabled'
       Pattern='EnableActiveProbing"?\s*/t\s*REG_DWORD\s*/d\s*"?0\b' },
    @{ Id='NCSI-POL'; Sev='BLOCK'; Desc='NoActiveProbe forced on'
       Pattern='NoActiveProbe"?\s*/t\s*REG_DWORD\s*/d\s*"?1\b' },
    @{ Id='OVERLAY';  Sev='BLOCK'; Desc='NVIDIA overlay disabled in registry'
       Pattern='DisableOverlay"?\s*/t\s*REG_DWORD\s*/d\s*"?1\b' },
    @{ Id='NV-DAEMON';Sev='BLOCK'; Desc='NVIDIA daemon suppressed'
       Pattern='NoDaemon"?\s*/t\s*REG_DWORD\s*/d\s*"?1\b' },
    @{ Id='NV-TRAY';  Sev='BLOCK'; Desc='NVIDIA tray start-on-login disabled'
       Pattern='StartOnLogin"?\s*/t\s*REG_DWORD\s*/d\s*"?0\b' },
    @{ Id='NETSH';    Sev='BLOCK'; Desc='network adapter set admin=disabled'
       Pattern='netsh\s+interface\s+set\s+interface\s+\S+\s+admin\s*=\s*disabled' }
)

$SetPattern  = 'set\s+"?(?<var>\w+)"?\s*=\s*(?<val>[^\r\n"]+)'
$LoopPattern = 'for\s+%\S*\s+in\s+\(%(\w+)%\)\s+do\s+sc(\.exe)?\s+config\s+%\S+\s+start\s*=\s*disabled'

# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------

$files = Get-ChildItem -LiteralPath $Path -File -Include *.bat, *.cmd -Recurse | Sort-Object Name
if (-not $files) {
    Write-Host "audit: no .bat/.cmd files under $Path" -ForegroundColor Red
    exit 2
}

$results = @()

foreach ($file in $files) {
    $text   = $enc.GetString([IO.File]::ReadAllBytes($file.FullName))
    $lines  = $text -split "`r`n"
    $bareLF = ([regex]::Matches($text, "(?<!\r)\n")).Count
    $crlf   = ([regex]::Matches($text, "`r`n")).Count

    $findings = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $raw = $lines[$i]
        $t   = $raw.Trim()
        if ($t -eq '') { continue }
        if ($t.StartsWith('::') -or $t -match '^(?i)rem\b') { continue }

        foreach ($rule in $Rules) {
            if ($raw -match $rule.Pattern) {
                $findings += [pscustomobject]@{
                    Line = $i + 1
                    Rule = $rule.Id
                    Sev  = $rule.Sev
                    Desc = $rule.Desc
                    Text = $t
                }
            }
        }
    }

    $sets = @{}
    foreach ($m in [regex]::Matches($text, $SetPattern)) {
        $sets[$m.Groups['var'].Value] = $m.Groups['val'].Value
    }
    foreach ($m in [regex]::Matches($text, $LoopPattern)) {
        $varName = $m.Groups[1].Value
        if (-not $sets.ContainsKey($varName)) { continue }
        $lineNo = ($text.Substring(0, $m.Index) -split "`r`n").Count
        $hit = (@($BlockNetServices) + @($WarnNetServices)) |
               Where-Object { $sets[$varName] -match "(?i)\b$_\b" } | Select-Object -Unique
        if ($hit) {
            $sev = if ($hit | Where-Object { $BlockNetServices -contains $_ }) { 'BLOCK' } else { 'WARN' }
            $findings += [pscustomobject]@{
                Line = $lineNo
                Rule = 'NET-LOOP'
                Sev  = $sev
                Desc = "batch loop disables service(s): $($hit -join ', ')"
                Text = $m.Value.Trim()
            }
        }
    }

    $results += [pscustomobject]@{
        File     = $file.Name
        Size     = $file.Length
        Lines    = $lines.Count
        CRLF     = $crlf
        BareLF   = $bareLF
        Findings = $findings
    }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

$blockTotal = 0
$warnTotal  = 0

if (-not $Quiet) {
    foreach ($r in $results) {
        $blocks = @($r.Findings | Where-Object Sev -eq 'BLOCK')
        $warns  = @($r.Findings | Where-Object Sev -eq 'WARN')
        $blockTotal += $blocks.Count
        $warnTotal  += $warns.Count

        Write-Host ''
        Write-Host ("=== {0}  ({1:N0} bytes, {2:N0} lines) ===" -f $r.File, $r.Size, $r.Lines) -ForegroundColor Cyan

        if ($r.BareLF -gt 0) {
            Write-Host ("  EOL    : {0:N0} CRLF, {1:N0} bare LF  <-- BAD" -f $r.CRLF, $r.BareLF) -ForegroundColor Red
        } else {
            Write-Host ("  EOL    : {0:N0} CRLF, 0 bare LF" -f $r.CRLF) -ForegroundColor DarkGray
        }

        if ($blocks.Count -eq 0) {
            Write-Host '  BLOCK  : 0' -ForegroundColor Green
        } else {
            Write-Host ("  BLOCK  : {0}" -f $blocks.Count) -ForegroundColor Red
            foreach ($f in $blocks) {
                Write-Host ("    {0,6} | [{1}] {2}" -f $f.Line, $f.Rule, $f.Desc) -ForegroundColor Red
                Write-Host ("           {0}" -f $f.Text) -ForegroundColor DarkRed
            }
        }

        if ($warns.Count -gt 0) {
            Write-Host ("  WARN   : {0}  (documented side effect, does not fail)" -f $warns.Count) -ForegroundColor Yellow
            foreach ($f in $warns) {
                Write-Host ("    {0,6} | [{1}] {2}" -f $f.Line, $f.Rule, $f.Desc) -ForegroundColor Yellow
                Write-Host ("           {0}" -f $f.Text) -ForegroundColor DarkYellow
            }
        }
    }
} else {
    foreach ($r in $results) {
        $blockTotal += @($r.Findings | Where-Object Sev -eq 'BLOCK').Count
        $warnTotal  += @($r.Findings | Where-Object Sev -eq 'WARN').Count
    }
}

$badEol = @($results | Where-Object BareLF -gt 0).Count

Write-Host ''
if ($badEol -gt 0) {
    Write-Host "AUDIT FAIL  -  $badEol file(s) lost CRLF" -ForegroundColor Red
    exit 1
}
if ($blockTotal -gt 0) {
    Write-Host ("AUDIT FAIL  -  {0} file(s), {1} blocking finding(s), {2} warning(s)" -f $results.Count, $blockTotal, $warnTotal) -ForegroundColor Red
    exit 1
}
if ($Strict -and $warnTotal -gt 0) {
    Write-Host ("AUDIT FAIL (strict)  -  {0} warning(s)" -f $warnTotal) -ForegroundColor Red
    exit 1
}

Write-Host ("AUDIT PASS  -  {0} file(s), 0 blocking findings, {1} documented warning(s)" -f $results.Count, $warnTotal) -ForegroundColor Green
exit 0
