#!/bin/sh
# Claude Code status line - portable across Windows (Git Bash), macOS and Linux.
# The Windows-native counterpart is statusline.ps1; keep both in sync via tests/.
input=$(cat)

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# One jq pass for everything we need. The status line runs on every render, so
# keep the process count down.
{ read -r model; read -r dir; read -r cpct; read -r ctok; } <<EOF
$(printf '%s' "$input" | jq -r '
  def hum: if . >= 1000000 then "\((. / 100000 | round) / 10)M"
           elif . >= 1000 then "\(. / 1000 | round)k"
           else tostring end;
  (.model.display_name // "?"),
  (.workspace.current_dir // .cwd // "."),
  (.context_window.used_percentage as $p | if $p == null then "" else ($p | round | tostring) end),
  (if .context_window.used_percentage == null then ""
   else "\(.context_window.total_input_tokens // 0 | hum)/\(.context_window.context_window_size // 0 | hum)"
   end)
' | tr -d '\r')
EOF

# Abbreviate the home directory to ~.
# On Windows current_dir looks like C:\... and home is $USERPROFILE; on Unix it
# is $HOME. Normalise to forward slashes for the comparison, then restore
# backslashes if the original path used them.
case "$dir" in *\\*) win=1 ;; *) win="" ;; esac
nd=$(printf '%s' "$dir" | tr '\\' '/')
disp="$nd"
for h in "$USERPROFILE" "$HOME"; do
  [ -z "$h" ] && continue
  nh=$(printf '%s' "$h" | tr '\\' '/')
  case "$nd" in
    "$nh") disp="~"; break ;;
    "$nh"/*) disp="~${nd#"$nh"}"; break ;;
  esac
done
[ -n "$win" ] && disp=$(printf '%s' "$disp" | tr '/' '\\')

# Show the branch only inside a git repository (skip the optional lock).
branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

# File age in seconds; a very large value when the file is missing.
# Do NOT use find here - on Windows, find.exe shadows GNU find in the PATH
# Claude Code runs the status line with.
# stat differs between GNU (-c) and BSD (-f), so try both.
now=$(date +%s)
age() {
  m=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null)
  [ -z "$m" ] && m=0
  AGE=$((now - m))
}

# The 5h/7d limits are not in stdin, so they need an authenticated API call.
# The status line runs on every render and must never block: read the cache
# only, and kick off a background refresh when it is older than a minute.
uc="$cfg/.cc-status-lite-cache.json"
age "$uc.stamp"
if [ "$AGE" -ge 60 ]; then
  : > "$uc.stamp"   # stamp first so concurrent renders do not all fetch
  (
    # Token lookup: the macOS keychain, otherwise .credentials.json.
    # Note: with CLAUDE_CONFIG_DIR set, the keychain service name becomes
    #       "...-<hash>". That combination is unsupported - add the first 8
    #       characters of the sha256 hash here if it is ever needed.
    tok=""
    if [ "$(uname -s)" = Darwin ]; then
      raw=$(security find-generic-password -s 'Claude Code-credentials' -a "$USER" -w 2>/dev/null \
            || security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null)
      tok=$(printf '%s' "$raw" | jq -r '(.claudeAiOauth // .).accessToken // empty' 2>/dev/null)
    fi
    [ -z "$tok" ] && tok=$(jq -r '(.claudeAiOauth // .).accessToken // empty' \
                           "$cfg/.credentials.json" 2>/dev/null | tr -d '\r')
    [ -z "$tok" ] && exit 0
    # The token is never passed as a curl argument: process arguments are world
    # readable through ps (macOS) and /proc/PID/cmdline (Linux), which would let
    # any other local user - or any unprivileged process, without unlocking the
    # keychain - read it. --config - takes the headers over stdin instead, so
    # the token never reaches the command line or the disk.
    #
    # No token refresh happens here. Once it expires the values simply go dim
    # and Claude Code restores them the next time it refreshes credentials.
    umask 077
    tmp="$uc.tmp.$$"   # PID suffix: several sessions may refresh concurrently
    printf 'silent\nfail\nmax-time = 10\nheader = "Authorization: Bearer %s"\nheader = "anthropic-beta: oauth-2025-04-20"\n' "$tok" \
      | curl --config - https://api.anthropic.com/api/oauth/usage 2>/dev/null \
      | jq -c '{five_hour:  {utilization: .five_hour.utilization,  resets_at: .five_hour.resets_at},
                seven_day: {utilization: .seven_day.utilization, resets_at: .seven_day.resets_at}}' \
        > "$tmp" 2>/dev/null
    # Store only the four fields the status line renders. The full response also
    # carries spend and credit balances, which we never display and therefore
    # have no reason to keep on disk.
    if [ -s "$tmp" ]; then mv -f "$tmp" "$uc"; else rm -f "$tmp"; fi
  ) >/dev/null 2>&1 &
fi

h5=""; h5r=""; d7=""; d7r=""
age "$uc"; cache_age=$AGE
if [ -f "$uc" ]; then
  # resets_at looks like "2026-07-27T10:40:00.455018+00:00" (UTC). Drop the
  # fractional seconds and the offset, append Z, then convert with
  # strflocaltime. The date command is deliberately avoided: GNU's -d does not
  # exist on macOS, which would break portability.
  { read -r h5; read -r h5r; read -r d7; read -r d7r; } <<EOF
$(jq -r '
  def pct: if . == null then "" else (round | tostring) end;
  def loc: try (.[0:19] + "Z" | fromdateiso8601 | strflocaltime("%m/%d %H:%M")) catch "";
  (.five_hour.utilization | pct),
  (.five_hour.resets_at // "" | loc),
  (.seven_day.utilization | pct),
  (.seven_day.resets_at // "" | loc)
' "$uc" 2>/dev/null | tr -d '\r')
EOF
fi

e=$(printf '\033')
GREEN="$e[32m"; YELLOW="$e[33m"; RED="$e[31m"; DIM="$e[2m"; RESET="$e[0m"
# Thresholds match the official documentation example: 70% warning, 90% danger.
# Set without a subshell.
#   $C  = percentage colour
#   $CR = reset-time colour - dim normally, promoted to match the percentage
#         once it crosses 70%
stale=""
c_of() {
  if [ -n "$stale" ]; then C=$DIM; CR=$DIM
  elif [ "$1" -ge 90 ]; then C=$RED; CR=$RED
  elif [ "$1" -ge 70 ]; then C=$YELLOW; CR=$YELLOW
  else C=$GREEN; CR=$DIM; fi
}

line1="[$model] $disp"
[ -n "$branch" ] && line1="$line1 ($branch)"

line2=""
# Two spaces between segments, but never at the start of the line - the context
# percentage is absent until the session has used some tokens.
add() { if [ -z "$line2" ]; then line2="$1"; else line2="$line2  $1"; fi; }

[ -n "$cpct" ] && { c_of "$cpct"; add "🧠 $C$cpct%$RESET $DIM($ctok)$RESET"; }
# After 15 minutes without a successful refresh, dim the values rather than
# hiding them: they stay visible, just marked as no longer current.
[ "$cache_age" -ge 900 ] && stale=1
[ -n "$h5" ] && { c_of "$h5"; seg="⏳ 5h $C$h5%$RESET"
                  [ -n "$h5r" ] && seg="$seg $CR($h5r)$RESET"
                  add "$seg"; }
[ -n "$d7" ] && { c_of "$d7"; seg="📅 7d $C$d7%$RESET"
                  [ -n "$d7r" ] && seg="$seg $CR($d7r)$RESET"
                  add "$seg"; }

printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"
exit 0
