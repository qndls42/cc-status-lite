#!/bin/sh
# statusline-pro installer: copy the script into the config directory and write
# the statusLine key in settings.json.
#
# Plugins cannot set the main statusLine key - the documentation allows only
# agent and subagentStatusLine - so this one write is unavoidable. From then on
# the SessionStart hook keeps the copy in sync with the plugin, and no
# reinstall is needed after an update.
set -e

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dest="$cfg/statusline-pro.sh"
settings="$cfg/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but was not found."
  echo
  echo "  macOS   : brew install jq"
  echo "  Linux   : sudo apt install jq   (or dnf/pacman equivalent)"
  echo "  Windows : winget install jqlang.jq"
  echo
  echo "Install jq, then run this again. On Windows you can skip jq entirely by"
  echo "using the PowerShell installer instead: scripts/install.ps1"
  exit 1
fi

mkdir -p "$cfg"
cp "$root/scripts/statusline.sh" "$dest"
chmod +x "$dest" 2>/dev/null || true

[ -f "$settings" ] || printf '{}\n' > "$settings"

# Leave a broken settings.json alone.
if ! jq -e . "$settings" >/dev/null 2>&1; then
  echo "ERROR: $settings is not valid JSON. Fix it by hand and run this again."
  exit 1
fi

# Keep any pre-existing status line that is not ours, so it can be restored.
prev=$(jq -r '.statusLine.command // empty' "$settings")
case "$prev" in
  ''|*statusline-pro*) ;;
  *)
    printf '%s\n' "$prev" > "$cfg/.statusline-pro-previous"
    echo "Backed up your existing status line: $prev"
    ;;
esac

# Use the ~ form for the default config directory (the shape Claude Code
# documents); fall back to an absolute path for a custom one.
case "$cfg" in
  "$HOME/.claude") cmd='bash ~/.claude/statusline-pro.sh' ;;
  *) cmd="bash \"$dest\"" ;;
esac

cp "$settings" "$settings.bak.statusline-pro"
tmp="$settings.tmp.$$"
jq --arg c "$cmd" '.statusLine = {"type": "command", "command": $c}' "$settings" > "$tmp"
mv -f "$tmp" "$settings"

echo "Installed."
echo "  script   : $dest"
echo "  settings : $settings  (backup: $settings.bak.statusline-pro)"
echo "  command  : $cmd"
echo
echo "Preview:"
printf '{"model":{"display_name":"Test"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000}}\n' "$HOME" \
  | sh "$dest" || true
echo
echo "The status line appears in new sessions. The 5h/7d figures need up to a"
echo "minute for their first refresh."
