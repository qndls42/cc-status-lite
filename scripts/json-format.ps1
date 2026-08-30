# Shared by install.ps1 and uninstall.ps1.
#
# ConvertTo-Json on Windows PowerShell 5.1 indents by aligning nested values
# under the key that introduces them, and puts two spaces after every colon.
# A settings.json of 4.6 KB comes back at 10.9 KB with lines approaching 400
# characters. Nothing breaks - it is still valid JSON and Claude Code reads it
# the same - but installing a status line should not reshape a file the user
# and other tools also edit, and the shell installer (which goes through jq)
# leaves a different shape again.
#
# Format-Json re-lays-out the whitespace of already-valid JSON to match what jq
# produces: two spaces per level, one space after the colon. It never touches
# anything inside a string literal.

function Format-Json([string]$json) {
    $sb = New-Object Text.StringBuilder
    $indent = 0
    $inStr = $false
    $esc = $false
    $c = $json.ToCharArray()

    for ($i = 0; $i -lt $c.Length; $i++) {
        $ch = $c[$i]

        # Inside a string literal everything is copied verbatim; only a
        # backslash-escaped quote does not end it.
        if ($inStr) {
            [void]$sb.Append($ch)
            if ($esc) { $esc = $false }
            elseif ($ch -eq '\') { $esc = $true }
            elseif ($ch -eq '"') { $inStr = $false }
            continue
        }

        if ($ch -eq '"') { $inStr = $true; [void]$sb.Append($ch); continue }

        # Structural whitespace is dropped and re-emitted below.
        if ($ch -eq ' ' -or $ch -eq "`t" -or $ch -eq "`r" -or $ch -eq "`n") { continue }

        if ($ch -eq '{' -or $ch -eq '[') {
            $close = if ($ch -eq '{') { '}' } else { ']' }
            # An empty container stays on one line, the way jq prints it.
            $j = $i + 1
            while ($j -lt $c.Length -and
                   ($c[$j] -eq ' ' -or $c[$j] -eq "`t" -or $c[$j] -eq "`r" -or $c[$j] -eq "`n")) { $j++ }
            if ($j -lt $c.Length -and $c[$j] -eq $close) {
                [void]$sb.Append($ch); [void]$sb.Append($close)
                $i = $j
                continue
            }
            $indent++
            [void]$sb.Append($ch + "`n" + ('  ' * $indent))
            continue
        }

        if ($ch -eq '}' -or $ch -eq ']') {
            $indent--
            [void]$sb.Append("`n" + ('  ' * $indent) + $ch)
            continue
        }

        if ($ch -eq ',') { [void]$sb.Append("," + "`n" + ('  ' * $indent)); continue }
        if ($ch -eq ':') { [void]$sb.Append(': '); continue }

        [void]$sb.Append($ch)
    }

    return $sb.ToString()
}

# Serialise settings for writing. The reformatted text is parsed back and
# compared against the untouched serialisation before it is returned: if
# Format-Json ever gets something wrong, this falls back to PowerShell's own
# output rather than writing a file it cannot vouch for. The worst case is the
# ugly formatting we started with - never a damaged settings.json.
function ConvertTo-SettingsJson($obj) {
    $raw = $obj | ConvertTo-Json -Depth 100
    try {
        $pretty = Format-Json $raw
        $before = ConvertFrom-Json $raw    | ConvertTo-Json -Depth 100 -Compress
        $after  = ConvertFrom-Json $pretty | ConvertTo-Json -Depth 100 -Compress
        if ($before -eq $after) { return $pretty + "`n" }
    } catch { }
    return $raw + "`n"
}
