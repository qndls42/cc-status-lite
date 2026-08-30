# cc-status-lite uninstaller, Windows-native counterpart of uninstall.sh.
# Restores the previous status line (or drops the key) and removes the files
# this plugin created.
$ErrorActionPreference = 'Stop'

. (Join-Path (Split-Path -Parent $PSCommandPath) 'json-format.ps1')

$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$settings = Join-Path $cfg 'settings.json'
$prevfile = Join-Path $cfg '.cc-status-lite-previous'

if (-not (Test-Path -LiteralPath $settings)) {
    Write-Output "$settings does not exist. Nothing to do."
    exit 0
}

try {
    $raw = (Get-Content -LiteralPath $settings -Raw -Encoding UTF8) -replace ('^' + [char]0xFEFF), ''
    $obj = ConvertFrom-Json $raw
} catch {
    Write-Output "ERROR: $settings is not valid JSON. Fix it by hand and run this again."
    exit 1
}

$cur = ''
if ($obj.statusLine) { $cur = [string]$obj.statusLine.command }
if ($cur -notlike '*cc-status-lite*') {
    $shown = if ($cur) { $cur } else { '(none)' }
    Write-Output "The current status line is not cc-status-lite: $shown"
    Write-Output "Leaving it untouched."
    exit 0
}

if (Test-Path -LiteralPath $prevfile) {
    $prev = ((Get-Content -LiteralPath $prevfile -Raw -Encoding UTF8) -replace ('^' + [char]0xFEFF), '').Trim()
    $obj.statusLine = [pscustomobject]@{ type = 'command'; command = $prev }
    Write-Output "Restored your previous status line: $prev"
    Remove-Item -LiteralPath $prevfile -Force
} else {
    $obj.PSObject.Properties.Remove('statusLine')
    Write-Output "Removed the statusLine key."
}

$tmp = "$settings.tmp.$PID"
# Windows PowerShell's -Encoding UTF8 prepends a BOM. settings.json is read
# by jq in the shell scripts and by Claude Code itself, so write it clean.
[IO.File]::WriteAllText($tmp, (ConvertTo-SettingsJson $obj),
                        (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $settings -Force

foreach ($f in @('cc-status-lite.ps1', 'cc-status-lite.sh', '.cc-status-lite-cache.json',
                 '.cc-status-lite-cache.json.stamp', '.cc-status-lite-nudged',
                 '.cc-status-lite-legacy-noted')) {
    Remove-Item -LiteralPath (Join-Path $cfg $f) -Force -ErrorAction SilentlyContinue
}
Get-ChildItem -LiteralPath $cfg -Filter '.cc-status-lite-cache.json.tmp.*' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Output "Uninstalled. New sessions will reflect the change."
