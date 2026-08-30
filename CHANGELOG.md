# Changelog

## 2.0.0

First public release, distributed as a plugin marketplace.

### Breaking

- **Installation moved to the marketplace.** Cloning into `~/.claude/skills/`
  is no longer supported: it registers the same skills a second time and the
  auto-update hook has no plugin root to work from. Install with
  `/plugin marketplace add qndls42/statusline-pro`, then delete the old clone.

### Added

- **Updates without a reinstall.** A `SessionStart` hook compares the installed
  copy against the plugin's and refreshes it when they differ, so `/plugin
  update` is all that is needed. It also offers setup once when no status line
  is configured, and stays silent when another status line is.
- **Native Windows support.** `statusline.ps1`, `install.ps1`, `uninstall.ps1`
  and a PowerShell hook, so Windows needs neither Git Bash nor `jq`.
- **Shared test suite.** `tests/cases/` is read by both `run-tests.sh` and
  `run-tests.ps1`, holding the two implementations to one set of expectations.
- `LICENSE` (MIT), matching the licence the manifest already declared.
- English documentation, with `README.ko.md` for Korean.

### Security

- **The OAuth token is no longer passed as a command-line argument.** Process
  arguments are readable through `ps` and `/proc/<pid>/cmdline`, so any other
  local user - or an unprivileged process that cannot open the keychain - could
  read it during each refresh. The header now goes over stdin via
  `curl --config -`, and the PowerShell implementation keeps it in memory.
- **The usage cache is now mode `600` and holds only four fields.** It
  previously stored the full API response, including spend and credit balances
  the status line never displays, in a world-readable file.

### Fixed

- The second line no longer starts with two spaces when the context percentage
  is absent, which is the case until a session has used some tokens.
- Concurrent refreshes no longer share one temporary file name.

## 1.1.0

- Show the local time each limit resets: `n% (MM/DD HH:MM)`.
- Convert timestamps with `jq`'s `strflocaltime` rather than `date -d`, which
  does not exist on macOS.
- The reset time is dim below 70% and takes the percentage's colour above it.

## 1.0.0

- Two-line status line: context usage plus the 5-hour and weekly limits.
- Shared path abbreviation and credential lookup across Windows (Git Bash),
  macOS and Linux.
- Usage responses cached for a minute and refreshed in the background so
  rendering never blocks.
- `install.sh` / `uninstall.sh`, and the `/statusline-install` and
  `/statusline-uninstall` skills.
