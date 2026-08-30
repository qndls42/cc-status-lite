# Shared-case test runner for the PowerShell implementation.
# It reads the same tests/cases/ directory as run-tests.sh, so both
# implementations are held to one set of expectations.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1
#   ... -Update    rewrite expected.txt from actual output
#
# Each case directory may contain:
#   input.json     stdin for the status line (required)
#   cache.json     a .cc-status-lite-cache.json fixture (optional)
#   expected.txt   exact expected output, with \e standing in for ESC
#   expected.re    a regular expression, used instead of expected.txt
#   opts           key=value lines; cache_age=<seconds> backdates cache.json
#
# Placeholders substituted in input.json: {HOME}, {DIR}
param([switch]$Update)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script = Join-Path $root 'scripts\statusline.ps1'
$psExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$esc = [char]27

$pass = 0
$fail = 0
$updated = 0

function Invoke-StatusLine($inputText, $sandbox) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    # ArgumentList does not exist on .NET Framework, so Windows PowerShell 5.1
    # needs the single Arguments string.
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    # A fresh sandbox per case: the home directory is redirected so ~
    # abbreviation is testable and no real repository is in scope for the
    # branch lookup.
    $psi.EnvironmentVariables['USERPROFILE'] = $sandbox
    $psi.EnvironmentVariables['HOME'] = $sandbox
    $psi.EnvironmentVariables['CLAUDE_CONFIG_DIR'] = (Join-Path $sandbox '.claude')

    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($inputText)
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd()
    [void]$p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return $out.TrimEnd("`r", "`n")
}

foreach ($caseDir in (Get-ChildItem -LiteralPath (Join-Path $root 'tests\cases') -Directory | Sort-Object Name)) {
    $name = $caseDir.Name
    $inputFile = Join-Path $caseDir.FullName 'input.json'
    if (-not (Test-Path -LiteralPath $inputFile)) { continue }

    $sandbox = Join-Path ([IO.Path]::GetTempPath()) ("cc-status-lite-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $sandbox 'work') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $sandbox '.claude') -Force | Out-Null

    $cacheAge = 0
    $optsFile = Join-Path $caseDir.FullName 'opts'
    if (Test-Path -LiteralPath $optsFile) {
        foreach ($line in (Get-Content -LiteralPath $optsFile -Encoding UTF8)) {
            if ($line -match '^\s*cache_age\s*=\s*(\d+)\s*$') { $cacheAge = [int]$Matches[1] }
        }
    }

    $cacheFile = Join-Path $caseDir.FullName 'cache.json'
    $destCache = Join-Path $sandbox '.claude\.cc-status-lite-cache.json'
    if (Test-Path -LiteralPath $cacheFile) {
        Copy-Item -LiteralPath $cacheFile -Destination $destCache -Force
        if ($cacheAge -gt 0) {
            (Get-Item -LiteralPath $destCache).LastWriteTime = (Get-Date).AddSeconds(-$cacheAge)
        }
    }
    # A fresh stamp keeps the background refresh from firing: tests must never
    # reach the network.
    New-Item -ItemType File -Path (Join-Path $sandbox '.claude\.cc-status-lite-cache.json.stamp') -Force | Out-Null

    # Substitute forward-slash paths. Two reasons: they need no JSON escaping
    # (a backslash would, and -replace's replacement string does not treat a
    # backslash as an escape, which made the earlier attempt double them), and
    # the status line then prints ~/work on every platform, so one expected.txt
    # serves both runners. Backslash handling has its own case instead.
    $homeFwd = $sandbox.Replace('\', '/')
    $dirFwd = (Join-Path $sandbox 'work').Replace('\', '/')
    $inputText = (Get-Content -LiteralPath $inputFile -Raw -Encoding UTF8).
        Replace('{HOME}', $homeFwd).
        Replace('{DIR}', $dirFwd)

    $actual = Invoke-StatusLine $inputText $sandbox
    $actualEsc = $actual.Replace([string]$esc, '\e')

    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue

    $reFile = Join-Path $caseDir.FullName 'expected.re'
    if (Test-Path -LiteralPath $reFile) {
        # The pattern is written so that grep -E and .NET agree: \\e matches a
        # literal backslash followed by e, which is how ESC is spelled in the
        # comparison strings.
        $re = ((Get-Content -LiteralPath $reFile -Raw -Encoding UTF8).Trim())
        if ($actualEsc -match $re) {
            $pass++; Write-Output "  ok    $name"
        } else {
            $fail++; Write-Output "  FAIL  $name"
            Write-Output "        expected to match: $re"
            Write-Output "        actual:            $actualEsc"
        }
        continue
    }

    $expectedFile = Join-Path $caseDir.FullName 'expected.txt'
    if ($Update) {
        # Not Set-Content -Encoding UTF8: on Windows PowerShell that writes a
        # BOM, which the shell runner would then compare byte for byte.
        [IO.File]::WriteAllText($expectedFile, $actualEsc + "`n",
                                (New-Object Text.UTF8Encoding($false)))
        Write-Output "  wrote $name"
        $updated++
        continue
    }

    $expected = ''
    if (Test-Path -LiteralPath $expectedFile) {
        $expected = (Get-Content -LiteralPath $expectedFile -Raw -Encoding UTF8).TrimEnd("`r", "`n") -replace "`r`n", "`n"
    }
    if ($actualEsc -eq $expected) {
        $pass++; Write-Output "  ok    $name"
    } else {
        $fail++; Write-Output "  FAIL  $name"
        Write-Output "        expected: $expected"
        Write-Output "        actual:   $actualEsc"
    }
}

Write-Output ""
# In update mode most cases are rewritten rather than compared, so reporting
# them as "passed" would be misleading - only the regex cases are still checked.
if ($Update) {
    Write-Output "$updated updated, $pass verified by pattern, $fail failed"
} else {
    Write-Output "$pass passed, $fail failed"
}
if ($fail -gt 0) { exit 1 }
