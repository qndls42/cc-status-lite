---
name: statusline-install
description: Install the statusline-pro status line. Use when the user says "install the status line", "statusline install", "/statusline-install", or otherwise asks to turn statusline-pro on.
---

# Install statusline-pro

Run the installer for the user's platform and report its output verbatim.

macOS, Linux, or Windows with Git Bash:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"
```

Windows without Git Bash (or when `jq` is not installed):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/install.ps1"
```

## Rules

- The script does the work. Never edit `settings.json` by hand.
- If it fails because `jq` is missing, pass the printed install command to the
  user. Do not install `jq` for them. On Windows, offer `install.ps1` instead -
  it needs neither `jq` nor Git Bash.
- If the script prints "Backed up your existing status line", **tell the user**.
  Another status line was replaced, and `/statusline-uninstall` restores it.
- Close by saying: the status line appears in new sessions, and the 5h/7d
  figures need up to a minute for their first refresh.
- Updates need no action. A SessionStart hook keeps the installed copy in sync
  with the plugin, so `/plugin update` is enough.

## What gets installed

```
[Opus 5] ~/my-project (main)
🧠 32% (64k/200k)  ⏳ 5h 21% (07/27 19:40)  📅 7d 30% (07/30 08:59)
```

- 🧠 context usage: percentage, tokens used, context window size
- ⏳ 5-hour limit, 📅 weekly limit - in brackets, the local time each one resets
- Colours: yellow at 70%, red at 90%. The reset time is dim until the
  percentage reaches 70%, then it takes the same colour.
- If a refresh fails for more than 15 minutes the values are dimmed rather than
  hidden, so they stay visible but marked as no longer current.

If the user reports that the 5h/7d values are missing, check the Troubleshooting
section of `${CLAUDE_PLUGIN_ROOT}/README.md`.
