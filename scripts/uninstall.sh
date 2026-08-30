#!/bin/sh
# cc-status-lite uninstaller: restore the previous status line (or drop the key)
# and remove the files this plugin created.
set -e

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"
prevfile="$cfg/.cc-status-lite-previous"

[ -f "$settings" ] || { echo "$settings does not exist. Nothing to do."; exit 0; }

cur=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)
case "$cur" in
  *cc-status-lite*) ;;
  *)
    echo "The current status line is not cc-status-lite: ${cur:-(none)}"
    echo "Leaving it untouched."
    exit 0 ;;
esac

tmp="$settings.tmp.$$"
if [ -f "$prevfile" ]; then
  prev=$(cat "$prevfile")
  jq --arg c "$prev" '.statusLine = {"type": "command", "command": $c}' "$settings" > "$tmp"
  echo "Restored your previous status line: $prev"
  rm -f "$prevfile"
else
  jq 'del(.statusLine)' "$settings" > "$tmp"
  echo "Removed the statusLine key."
fi
mv -f "$tmp" "$settings"

rm -f "$cfg/cc-status-lite.sh" "$cfg/cc-status-lite.ps1" \
      "$cfg/.cc-status-lite-cache.json" "$cfg/.cc-status-lite-cache.json.stamp" "$cfg/.cc-status-lite-cache.json.tmp"* \
      "$cfg/.cc-status-lite-nudged" "$cfg/.cc-status-lite-legacy-noted"
echo "Uninstalled. New sessions will reflect the change."
