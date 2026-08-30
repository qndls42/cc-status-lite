# cc-status-lite installer, Windows-native counterpart of install.sh.
# Needs neither jq nor Git Bash.
#
# Plugins cannot set the main statusLine key - the documentation allows only
# agent and subagentStatusLine - so this one write is unavoidable. From then on
# the SessionStart hook keeps the copy in sync with the plugin, and no
# reinstall is needed after an update.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$dest = Join-Path $cfg 'cc-status-lite.ps1'
$settings = Join-Path $cfg 'settings.json'

New-Item -ItemType Directory -Path $cfg -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'scripts\statusline.ps1') -Destination $dest -Force

if (-not (Test-Path -LiteralPath $settings)) {
    [IO.File]::WriteAllText($settings, '{}', (New-Object Text.UTF8Encoding($false)))
}

# Leave a broken settings.json alone.
try {
    # Strip a UTF-8 BOM: some editors prepend one and it breaks the parser.
    $raw = (Get-Content -LiteralPath $settings -Raw) -replace ('^' + [char]0xFEFF), ''
    $obj = ConvertFrom-Json $raw
} catch {
    Write-Output "ERROR: $settings is not valid JSON. Fix it by hand and run this again."
    exit 1
}
if ($null -eq $obj) { $obj = [pscustomobject]@{} }

# Keep any pre-existing status line that is not ours, so it can be restored.
$prev = ''
if ($obj.statusLine) { $prev = [string]$obj.statusLine.command }
if ($prev -and $prev -notlike '*cc-status-lite*') {
    $prev | Set-Content -LiteralPath (Join-Path $cfg '.cc-status-lite-previous') -Encoding UTF8
    Write-Output "Backed up your existing status line: $prev"
}

$cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$dest`""

Copy-Item -LiteralPath $settings -Destination "$settings.bak.cc-status-lite" -Force

$statusLine = [pscustomobject]@{ type = 'command'; command = $cmd }
if ($obj.PSObject.Properties.Name -contains 'statusLine') {
    $obj.statusLine = $statusLine
} else {
    $obj | Add-Member -MemberType NoteProperty -Name statusLine -Value $statusLine
}

# Write through a temporary file so an interrupted run cannot leave settings
# half written.
$tmp = "$settings.tmp.$PID"
# Windows PowerShell's -Encoding UTF8 prepends a BOM. settings.json is read
# by jq in the shell scripts and by Claude Code itself, so write it clean.
[IO.File]::WriteAllText($tmp, ($obj | ConvertTo-Json -Depth 100),
                        (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $settings -Force

Write-Output "Installed."
Write-Output "  script   : $dest"
Write-Output "  settings : $settings  (backup: $settings.bak.cc-status-lite)"
Write-Output "  command  : $cmd"
Write-Output ""
Write-Output "Preview:"
$sample = '{"model":{"display_name":"Test"},"workspace":{"current_dir":"' + ($env:USERPROFILE -replace '\\', '\\\\') + '"},"context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000}}'
$sample | & powershell -NoProfile -ExecutionPolicy Bypass -File $dest
Write-Output ""
Write-Output "The status line appears in new sessions. The 5h/7d figures need up to a"
Write-Output "minute for their first refresh."
