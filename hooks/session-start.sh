#!/bin/sh
# SessionStart hook. Two jobs, both cheap and quiet:
#   1. keep ~/.claude/cc-status-lite.sh identical to the copy inside the plugin
#   2. offer setup once, when no status line is configured at all
#
# Why the copy exists: plugins cannot set the main statusLine key (only agent
# and subagentStatusLine), and ${CLAUDE_PLUGIN_ROOT} is not expanded inside
# settings.json. The plugin's own directory is versioned, so its path changes
# on every update - settings.json therefore points at a stable copy, and this
# hook is what keeps that copy current.
#
# The Windows-native counterpart is session-start.ps1; keep both in sync.
set -u

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"
root="${CLAUDE_PLUGIN_ROOT:-}"
src="$root/scripts/statusline.sh"
dest="$cfg/cc-status-lite.sh"
nudged="$cfg/.cc-status-lite-nudged"
legacy_noted="$cfg/.cc-status-lite-legacy-noted"
legacy="$cfg/skills/cc-status-lite"

[ -n "$root" ] && [ -f "$src" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

cur=""
[ -f "$settings" ] && cur=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)

notes=""

# A pre-marketplace install left a git clone under ~/.claude/skills/. It still
# registers the same skills, so /statuslite-install shows up twice. Say so once.
if [ -d "$legacy" ] && [ ! -f "$legacy_noted" ]; then
  : > "$legacy_noted" 2>/dev/null
  notes="cc-status-lite is also present as an old manual clone at $legacy. It is now installed as a plugin, so that directory registers the same skills a second time. Tell the user they can delete it - do not delete it yourself."
fi

case "$cur" in
  *cc-status-lite.sh*)
    # Installed, shell variant. Repair the copy whenever it differs from the
    # plugin's version: this covers plugin updates, a hand-edited copy and a
    # truncated one alike.
    if ! cmp -s "$src" "$dest" 2>/dev/null; then
      cp "$src" "$dest" 2>/dev/null && chmod +x "$dest" 2>/dev/null
    fi
    ;;
  *cc-status-lite*)
    # Installed, but pointing at the PowerShell variant. session-start.ps1
    # owns that copy - leave it alone.
    ;;
  "")
    # No status line at all. Offer once - a flag file marks that the user has
    # already seen (and implicitly declined) the offer. Repeating it every
    # session turns a helpful hint into a nag.
    if [ ! -f "$nudged" ]; then
      : > "$nudged" 2>/dev/null
      [ -n "$notes" ] && notes="$notes
"
      notes="${notes}STATUSLINE SETUP NEEDED: the cc-status-lite plugin is installed but no status line is configured. It shows context usage plus the 5-hour and weekly limits with their reset times. To enable it, run: sh \"$root/scripts/install.sh\". Offer this to the user on the first interaction and only run it if they agree."
    fi
    ;;
  *)
    # Some other status line is configured. Not ours to touch, and not ours to
    # campaign against - stay quiet.
    ;;
esac

[ -n "$notes" ] || exit 0
jq -n --arg c "$notes" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}' 2>/dev/null
exit 0
