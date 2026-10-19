<#
.SYNOPSIS
    Builds the ACNX release archive and checksum manifest.

.DESCRIPTION
    Runs the auditor first. If the audit fails nothing is produced, so a release can never ship a
    script that breaks Wi-Fi, Ethernet or the NVIDIA overlay.

    Output:
      dist/ACNX-v<version>.zip
      dist/SHA256SUMS.txt
      dist/release-body.md   (generated from releases/v<version>.md)

.PARAMETER Version
    Overrides VERSION. Defaults to the content of the VERSION file.

.PARAMETER SkipAudit
    Builds without auditing. For local experiments only.

.EXAMPLE
    pwsh -File tools/build-release.ps1
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$SkipAudit
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$src  = Join-Path $root 'src'
$dist = Join-Path $root 'dist'

if (-not $Version) {
    $Version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
}
if (-not $Version) {
    throw 'VERSION is empty'
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "VERSION must look like 1.2.3 (got '$Version')"
}

Write-Host "building ACNX v$Version" -ForegroundColor Cyan

# --- 1. audit ---------------------------------------------------------------
if (-not $SkipAudit) {
    Write-Host 'running audit...' -ForegroundColor DarkGray
    & (Join-Path $PSScriptRoot 'audit-release.ps1') -Path $src -Quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'audit failed - release blocked'
    }
    Write-Host 'audit passed' -ForegroundColor Green
}

# --- 2. stage ---------------------------------------------------------------
if (Test-Path -LiteralPath $dist) {
    Remove-Item -LiteralPath $dist -Recurse -Force
}
$stage = Join-Path $dist "ACNX-v$Version"
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$scripts = Get-ChildItem -LiteralPath $src -File -Include *.bat, *.cmd -Recurse
if (-not $scripts) { throw "no scripts in $src" }

foreach ($s in $scripts) {
    Copy-Item -LiteralPath $s.FullName -Destination (Join-Path $stage $s.Name) -Force
}

foreach ($doc in 'README.md', 'LICENSE', 'CHANGELOG.md') {
    $p = Join-Path $root $doc
    if (Test-Path -LiteralPath $p) {
        Copy-Item -LiteralPath $p -Destination (Join-Path $stage $doc) -Force
    }
}

# --- 3. manifest ------------------------------------------------------------
$manifest = foreach ($s in Get-ChildItem -LiteralPath $stage -File | Sort-Object Name) {
    $h = (Get-FileHash -LiteralPath $s.FullName -Algorithm SHA256).Hash.ToLower()
    "$h  $($s.Name)"
}
$manifestPath = Join-Path $stage 'SHA256SUMS.txt'
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding ascii

# --- 4. archive -------------------------------------------------------------
$zip = Join-Path $dist "ACNX-v$Version.zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal

$zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
$sums = @($manifest) + @("$zipHash  ACNX-v$Version.zip")
Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Value $sums -Encoding ascii

# --- 5. release body --------------------------------------------------------
$notePath = Join-Path $root "releases\v$Version.md"
if (Test-Path -LiteralPath $notePath) {
    Copy-Item -LiteralPath $notePath -Destination (Join-Path $dist 'release-body.md') -Force
} else {
    Write-Warning "releases/v$Version.md not found - release body will be empty"
}

# --- 6. summary -------------------------------------------------------------
Write-Host ''
Write-Host "  archive : $zip" -ForegroundColor Green
Write-Host ("  size    : {0:N2} MB" -f ((Get-Item -LiteralPath $zip).Length / 1MB))
Write-Host ''
Write-Host '  SHA-256:' -ForegroundColor DarkGray
$sums | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
Write-Host ''
Write-Host 'next: git tag v' -NoNewline
Write-Host "$Version" -NoNewline
Write-Host ' && git push origin main --tags'
