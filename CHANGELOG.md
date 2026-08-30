# Changelog

## 2.0.0

First public release, distributed as a plugin marketplace.

### Breaking

- **Renamed from `statusline-pro` to `cc-status-lite`.** The old name collided
  with an existing project of the same name and said nothing about the plugin
  being lightweight. Everything moves with it: the repository, the marketplace
  and plugin names, the skills (`/statuslite-install`, `/statuslite-uninstall`),
  and the files written into the config directory. The usage cache is now
  namespaced as `.cc-status-lite-cache.json` rather than claiming the generic
  `.usage-cache.json`. Nobody was running the old name outside the author's own
  machines, so no migration path is carried in the code.
- **Installation moved to the marketplace.** Cloning into `~/.claude/skills/`
  is no longer supported: it registers the same skills a second time and the
  auto-update hook has no plugin root to work from. Install with
  `/plugin marketplace add qndls42/cc-status-lite`, then delete the old clone.

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

## 2.0.1

Windows fixes found by running the PowerShell implementation on Windows
PowerShell 5.1 for the first time. The shell implementation was unaffected.

### Fixed

- **The brain and calendar icons vanished from the status line.** They were
  built with `[char]`, and `System.Char` holds a single UTF-16 code unit, so a
  code point above U+FFFF throws and the surrounding expression silently
  collapses to an empty string. The hourglass survived only because it happens
  to sit in the BMP. Icons now go through `[char]::ConvertFromUtf32`.
- **Reset times printed as `08-30` instead of `08/30`.** In a .NET custom date
  format `/` is not a literal slash - it stands for the current culture's date
  separator, which is `-` under ko-KR. Formatting now goes through the
  invariant culture, matching what `strflocaltime` produces in the shell.
- **The test harness escaped sandbox paths twice**, so every PowerShell case
  failed on the home-directory abbreviation. Paths are now substituted with
  forward slashes, which need no JSON escaping and let one expected file serve
  both runners.

### Added

- `12-windows-path`, covering the backslash round-trip that Claude Code
  actually feeds the status line on Windows, and the half-away-from-zero
  rounding both implementations have to agree on.

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
- `install.sh` / `uninstall.sh`, and the `/statuslite-install` and
  `/statuslite-uninstall` skills.
