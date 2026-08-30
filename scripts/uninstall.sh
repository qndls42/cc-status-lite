#!/bin/sh
# statusline-pro uninstaller: restore the previous status line (or drop the key)
# and remove the files this plugin created.
set -e

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"
prevfile="$cfg/.statusline-pro-previous"

[ -f "$settings" ] || { echo "$settings does not exist. Nothing to do."; exit 0; }

cur=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)
case "$cur" in
  *statusline-pro*) ;;
  *)
    echo "The current status line is not statusline-pro: ${cur:-(none)}"
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

rm -f "$cfg/statusline-pro.sh" "$cfg/statusline-pro.ps1" \
      "$cfg/.usage-cache.json" "$cfg/.usage-cache.json.stamp" "$cfg/.usage-cache.json.tmp"* \
      "$cfg/.statusline-pro-nudged" "$cfg/.statusline-pro-legacy-noted"
echo "Uninstalled. New sessions will reflect the change."
