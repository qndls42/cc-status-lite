# SessionStart hook, Windows-native counterpart of session-start.sh.
# Keep the two in sync - tests/run-tests.ps1 covers the status line itself.
#
# Two jobs, both cheap and quiet:
#   1. keep cc-status-lite.ps1 in the config directory identical to the copy
#      inside the plugin
#   2. offer setup once, when no status line is configured at all
#
# Why the copy exists: plugins cannot set the main statusLine key, and
# ${CLAUDE_PLUGIN_ROOT} is not expanded inside settings.json. The plugin's own
# directory is versioned, so its path changes on every update - settings.json
# therefore points at a stable copy, and this hook keeps that copy current.

$ErrorActionPreference = 'SilentlyContinue'

$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$settings = Join-Path $cfg 'settings.json'
$root = $env:CLAUDE_PLUGIN_ROOT
if (-not $root) { exit 0 }

$src = Join-Path $root 'scripts\statusline.ps1'
$dest = Join-Path $cfg 'cc-status-lite.ps1'
$nudged = Join-Path $cfg '.cc-status-lite-nudged'
$legacyNoted = Join-Path $cfg '.cc-status-lite-legacy-noted'
$legacy = Join-Path $cfg 'skills\cc-status-lite'

if (-not (Test-Path -LiteralPath $src)) { exit 0 }

$cur = ''
if (Test-Path -LiteralPath $settings) {
    try {
        # Strip a UTF-8 BOM: some editors prepend one and it breaks the parser.
        $raw = (Get-Content -LiteralPath $settings -Raw -Encoding UTF8) -replace ('^' + [char]0xFEFF), ''
        $cur = ([string](ConvertFrom-Json $raw).statusLine.command)
    } catch { $cur = '' }
}

$notes = @()

# A pre-marketplace install left a manual clone under .claude\skills\. It still
# registers the same skills, so /statuslite-install shows up twice. Say so once.
if ((Test-Path -LiteralPath $legacy) -and -not (Test-Path -LiteralPath $legacyNoted)) {
    New-Item -ItemType File -Path $legacyNoted -Force | Out-Null
    $notes += "cc-status-lite is also present as an old manual clone at $legacy. It is now installed as a plugin, so that directory registers the same skills a second time. Tell the user they can delete it - do not delete it yourself."
}

if ($cur -like '*cc-status-lite.ps1*') {
    # Installed, PowerShell variant. Repair the copy whenever it differs from
    # the plugin's version: this covers plugin updates, a hand-edited copy and
    # a truncated one alike.
    $same = $false
    if (Test-Path -LiteralPath $dest) {
        $same = (Get-FileHash -LiteralPath $src).Hash -eq (Get-FileHash -LiteralPath $dest).Hash
    }
    if (-not $same) { Copy-Item -LiteralPath $src -Destination $dest -Force }
}
elseif ($cur -like '*cc-status-lite*') {
    # Installed, but pointing at the shell variant. session-start.sh owns that
    # copy - leave it alone.
}
elseif ([string]::IsNullOrEmpty($cur)) {
    # No status line at all. Offer once - a flag file marks that the user has
    # already seen (and implicitly declined) the offer.
    if (-not (Test-Path -LiteralPath $nudged)) {
        New-Item -ItemType File -Path $nudged -Force | Out-Null
        $notes += "STATUSLINE SETUP NEEDED: the cc-status-lite plugin is installed but no status line is configured. It shows context usage plus the 5-hour and weekly limits with their reset times. To enable it, run: powershell -NoProfile -ExecutionPolicy Bypass -File `"$root\scripts\install.ps1`". Offer this to the user on the first interaction and only run it if they agree."
    }
}
# Any other status line belongs to someone else: not ours to touch, and not
# ours to campaign against - stay quiet.

if ($notes.Count -eq 0) { exit 0 }

@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = ($notes -join "`n") } } |
    ConvertTo-Json -Depth 5 -Compress
exit 0
