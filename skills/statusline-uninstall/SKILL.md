---
name: statusline-uninstall
description: Remove the statusline-pro status line. Use when the user says "remove the status line", "statusline uninstall", "/statusline-uninstall", or asks to turn statusline-pro off.
---

# Uninstall statusline-pro

Run the uninstaller for the user's platform and report its output verbatim.

macOS, Linux, or Windows with Git Bash:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh"
```

Windows without Git Bash:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.ps1"
```

## Rules

- The script does the work. Never edit `settings.json` by hand - it holds the
  user's hooks, plugin list and marketplace configuration, and a hand edit
  risks all of it.
- The script removes only the `statusLine` key. Everything else is untouched.
- If a status line was backed up during install, it is restored and the script
  says so. Pass that on.
- If the current status line is not statusline-pro, the script exits without
  changing anything. Report that rather than forcing it.
- This removes the status line, not the plugin. To remove the plugin itself the
  user runs `/plugin uninstall statusline-pro@statusline-pro`.
