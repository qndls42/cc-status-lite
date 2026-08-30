# Claude Code status line, Windows-native counterpart of statusline.sh.
# Keep the two in sync - tests/cases/ is shared between both runners.
#
# Unlike the shell version this needs no jq and no Git Bash: PowerShell and
# ConvertFrom-Json ship with Windows.
param([switch]$Refresh)

$ErrorActionPreference = 'SilentlyContinue'

$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$cache = Join-Path $cfg '.cc-status-lite-cache.json'
$stamp = "$cache.stamp"

# ---------------------------------------------------------------------------
# Refresh mode: fetch the 5h/7d limits and rewrite the cache, then exit.
# Runs in a detached process so rendering is never blocked.
# ---------------------------------------------------------------------------
if ($Refresh) {
    # The token is read here rather than passed in: an argument would land in
    # the process command line, where any other local user could read it.
    $credPath = Join-Path $cfg '.credentials.json'
    if (-not (Test-Path -LiteralPath $credPath)) { exit 0 }
    try {
        $cred = ConvertFrom-Json ((Get-Content -LiteralPath $credPath -Raw -Encoding UTF8) -replace ('^' + [char]0xFEFF), '')
    } catch { exit 0 }
    $tok = if ($cred.claudeAiOauth) { $cred.claudeAiOauth.accessToken } else { $cred.accessToken }
    if (-not $tok) { exit 0 }

    # Windows PowerShell 5.1 still negotiates TLS 1.0 by default on some builds.
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

    try {
        $resp = Invoke-RestMethod -Uri 'https://api.anthropic.com/api/oauth/usage' -TimeoutSec 10 -Headers @{
            'Authorization'   = "Bearer $tok"
            'anthropic-beta'  = 'oauth-2025-04-20'
        }
    } catch { exit 0 }
    if (-not $resp) { exit 0 }

    # Store only the four fields the status line renders. The full response also
    # carries spend and credit balances, which we never display and therefore
    # have no reason to keep on disk. Files under the user profile are not
    # readable by other standard users, which is the ACL equivalent of the
    # chmod 600 the shell version applies.
    $slim = @{
        five_hour = @{ utilization = $resp.five_hour.utilization; resets_at = $resp.five_hour.resets_at }
        seven_day = @{ utilization = $resp.seven_day.utilization; resets_at = $resp.seven_day.resets_at }
    }
    $tmp = "$cache.tmp.$PID"   # PID suffix: several sessions may refresh at once
    try {
        # Windows PowerShell's -Encoding UTF8 prepends a BOM, which jq refuses
        # to parse - the shell implementation must be able to read this file.
        [IO.File]::WriteAllText($tmp, ($slim | ConvertTo-Json -Depth 5 -Compress),
                                (New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmp -Destination $cache -Force
    } catch { Remove-Item -LiteralPath $tmp -Force }
    exit 0
}

# ---------------------------------------------------------------------------
# Render mode
# ---------------------------------------------------------------------------
# Claude Code writes the JSON as UTF-8, but [Console]::In decodes with the
# console's input code page, which is the system ANSI one on Windows - a
# Korean path in current_dir came back as mojibake. Read the raw stream and
# decode it explicitly instead. Setting [Console]::InputEncoding is not an
# option here: it throws when stdin is a pipe, which is always the case.
# The output encoding is BOM-less on purpose; the BOM-carrying UTF8 instance
# can prepend one on the first write.
try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false) } catch { }

$reader = New-Object IO.StreamReader([Console]::OpenStandardInput(),
                                     (New-Object Text.UTF8Encoding($false)))
$raw = $reader.ReadToEnd()
try { $in = ConvertFrom-Json $raw } catch { exit 0 }

# jq rounds half away from zero; .NET rounds half to even by default. Match jq
# so both implementations agree on values such as 38.5.
function Round-Half([double]$n) { [math]::Round($n, [MidpointRounding]::AwayFromZero) }

$inv = [Globalization.CultureInfo]::InvariantCulture
function Format-Tokens([double]$n) {
    # Always format through the invariant culture: on a locale that uses a
    # comma as the decimal separator, "1.2M" would otherwise come out "1,2M"
    # and diverge from the shell implementation.
    if ($n -ge 1000000) {
        $m = (Round-Half ($n / 100000)) / 10
        # jq prints 1 rather than 1.0, so drop a trailing .0 the same way.
        return ($m.ToString($inv) -replace '\.0$', '') + 'M'
    }
    if ($n -ge 1000) { return (Round-Half ($n / 1000)).ToString($inv) + 'k' }
    return ([int]$n).ToString($inv)
}

$model = if ($in.model.display_name) { $in.model.display_name } else { '?' }
$dir = if ($in.workspace.current_dir) { $in.workspace.current_dir }
       elseif ($in.cwd) { $in.cwd } else { '.' }

$cpct = ''
$ctok = ''
if ($null -ne $in.context_window.used_percentage) {
    $cpct = (Round-Half ([double]$in.context_window.used_percentage)).ToString($inv)
    $used = if ($null -ne $in.context_window.total_input_tokens) { [double]$in.context_window.total_input_tokens } else { 0 }
    $size = if ($null -ne $in.context_window.context_window_size) { [double]$in.context_window.context_window_size } else { 0 }
    $ctok = "{0}/{1}" -f (Format-Tokens $used), (Format-Tokens $size)
}

# Abbreviate the home directory to ~. Compare on forward slashes, then restore
# backslashes when the original path used them.
$win = $dir -like '*\*'
$nd = $dir -replace '\\', '/'
$disp = $nd
foreach ($h in @($env:USERPROFILE, $env:HOME)) {
    if (-not $h) { continue }
    $nh = ($h -replace '\\', '/').TrimEnd('/')
    if ($nd -eq $nh) { $disp = '~'; break }
    if ($nd.StartsWith("$nh/")) { $disp = '~' + $nd.Substring($nh.Length); break }
}
if ($win) { $disp = $disp -replace '/', '\' }

# Show the branch only inside a git repository (skip the optional lock).
$branch = ''
try {
    $branch = (& git -C $dir --no-optional-locks branch --show-current 2>$null | Select-Object -First 1)
    if (-not $branch) {
        $branch = (& git -C $dir --no-optional-locks rev-parse --short HEAD 2>$null | Select-Object -First 1)
    }
} catch { $branch = '' }

function Get-AgeSeconds([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return [int]::MaxValue }
    return [int]((Get-Date) - (Get-Item -LiteralPath $path).LastWriteTime).TotalSeconds
}

# The 5h/7d limits are not in stdin, so they need an authenticated API call.
# The status line runs on every render and must never block: read the cache
# only, and kick off a detached refresh when it is older than a minute.
# The -not -Test-Path guard mirrors the shell version: with no config
# directory there is nowhere to write the stamp or the cache.
if ((Test-Path -LiteralPath $cfg) -and (Get-AgeSeconds $stamp) -ge 60) {
    New-Item -ItemType File -Path $stamp -Force | Out-Null   # stamp first, so
    # concurrent renders do not all fetch
    try {
        $psExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if (-not $psExe) { $psExe = 'powershell.exe' }
        Start-Process -FilePath $psExe -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Refresh'
        ) | Out-Null
    } catch { }
}

$h5 = ''; $h5r = ''; $d7 = ''; $d7r = ''
$cacheAge = Get-AgeSeconds $cache
if (Test-Path -LiteralPath $cache) {
    try {
        $u = ConvertFrom-Json ((Get-Content -LiteralPath $cache -Raw -Encoding UTF8) -replace ('^' + [char]0xFEFF), '')
        # resets_at looks like "2026-07-27T10:40:00.455018+00:00" (UTC).
        # DateTimeOffset handles the fractional seconds and the offset, and
        # LocalDateTime does the conversion.
        function Convert-Reset($s) {
            if (-not $s) { return '' }
            # '/' in a .NET custom date format is not a literal slash - it is a
            # placeholder for the current culture's date separator, which is '-'
            # under ko-KR and others. Format through the invariant culture so
            # both implementations print MM/dd.
            try {
                return ([datetimeoffset]::Parse($s)).LocalDateTime.ToString('MM/dd HH:mm', $inv)
            } catch { return '' }
        }
        if ($null -ne $u.five_hour.utilization) {
            $h5 = (Round-Half ([double]$u.five_hour.utilization)).ToString($inv)
            $h5r = Convert-Reset $u.five_hour.resets_at
        }
        if ($null -ne $u.seven_day.utilization) {
            $d7 = (Round-Half ([double]$u.seven_day.utilization)).ToString($inv)
            $d7r = Convert-Reset $u.seven_day.resets_at
        }
    } catch { }
}

$e = [char]27
$GREEN = "$e[32m"; $YELLOW = "$e[33m"; $RED = "$e[31m"; $DIM = "$e[2m"; $RESET = "$e[0m"

# Icons are built from code points rather than written literally: Windows
# PowerShell 5.1 reads a BOM-less script with the system ANSI code page, which
# would mangle literal emoji. [char] is not usable either - System.Char is a
# single UTF-16 code unit, so anything above U+FFFF throws and the surrounding
# expression silently collapses to an empty string. ConvertFromUtf32 returns
# the surrogate pair. All three icons here are astral: a BMP symbol such as
# the hourglass U+23F3 renders as a narrow monochrome glyph in most terminals,
# because the text font is found before the emoji font in the fallback chain.
$ICON_CTX = [char]::ConvertFromUtf32(0x1F9E0)   # brain, astral
$ICON_5H  = [char]::ConvertFromUtf32(0x1F550)   # clock face, astral
$ICON_7D  = [char]::ConvertFromUtf32(0x1F4C5)   # calendar, astral

# After 15 minutes without a successful refresh, dim the values rather than
# hiding them: they stay visible, just marked as no longer current. The context
# percentage comes from stdin and is never stale.
$stale = $cacheAge -ge 900

# Thresholds match the official documentation example: 70% warning, 90% danger.
#   colour  = percentage colour
#   resetCr = reset-time colour - dim normally, promoted to match the
#             percentage once it crosses 70%
function Get-Colours([int]$pct, [bool]$isStale) {
    if ($isStale) { return @($DIM, $DIM) }
    if ($pct -ge 90) { return @($RED, $RED) }
    if ($pct -ge 70) { return @($YELLOW, $YELLOW) }
    return @($GREEN, $DIM)
}

$line1 = "[$model] $disp"
if ($branch) { $line1 += " ($branch)" }

# Two spaces between segments, but never at the start of the line - the context
# percentage is absent until the session has used some tokens.
$segments = @()
if ($cpct -ne '') {
    $c = Get-Colours ([int]$cpct) $false
    $segments += "$ICON_CTX $($c[0])$cpct%$RESET $DIM($ctok)$RESET"
}
if ($h5 -ne '') {
    $c = Get-Colours ([int]$h5) $stale
    $seg = "$ICON_5H 5h $($c[0])$h5%$RESET"
    if ($h5r) { $seg += " $($c[1])($h5r)$RESET" }
    $segments += $seg
}
if ($d7 -ne '') {
    $c = Get-Colours ([int]$d7) $stale
    $seg = "$ICON_7D 7d $($c[0])$d7%$RESET"
    if ($d7r) { $seg += " $($c[1])($d7r)$RESET" }
    $segments += $seg
}
$line2 = $segments -join '  ' 

[Console]::Out.Write($line1 + "`n")
if ($line2) { [Console]::Out.Write($line2 + "`n") }
exit 0
