# statusline-pro uninstaller, Windows-native counterpart of uninstall.sh.
# Restores the previous status line (or drops the key) and removes the files
# this plugin created.
$ErrorActionPreference = 'Stop'

$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$settings = Join-Path $cfg 'settings.json'
$prevfile = Join-Path $cfg '.statusline-pro-previous'

if (-not (Test-Path -LiteralPath $settings)) {
    Write-Output "$settings does not exist. Nothing to do."
    exit 0
}

try {
    $raw = (Get-Content -LiteralPath $settings -Raw) -replace ('^' + [char]0xFEFF), ''
    $obj = ConvertFrom-Json $raw
} catch {
    Write-Output "ERROR: $settings is not valid JSON. Fix it by hand and run this again."
    exit 1
}

$cur = ''
if ($obj.statusLine) { $cur = [string]$obj.statusLine.command }
if ($cur -notlike '*statusline-pro*') {
    $shown = if ($cur) { $cur } else { '(none)' }
    Write-Output "The current status line is not statusline-pro: $shown"
    Write-Output "Leaving it untouched."
    exit 0
}

if (Test-Path -LiteralPath $prevfile) {
    $prev = (Get-Content -LiteralPath $prevfile -Raw).Trim()
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
[IO.File]::WriteAllText($tmp, ($obj | ConvertTo-Json -Depth 100),
                        (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $settings -Force

foreach ($f in @('statusline-pro.ps1', 'statusline-pro.sh', '.usage-cache.json',
                 '.usage-cache.json.stamp', '.statusline-pro-nudged',
                 '.statusline-pro-legacy-noted')) {
    Remove-Item -LiteralPath (Join-Path $cfg $f) -Force -ErrorAction SilentlyContinue
}
Get-ChildItem -LiteralPath $cfg -Filter '.usage-cache.json.tmp.*' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Output "Uninstalled. New sessions will reflect the change."
