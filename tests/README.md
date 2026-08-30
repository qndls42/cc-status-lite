# Tests

`cases/` holds one directory per case, shared by both runners:

```
sh tests/run-tests.sh                                              # macOS / Linux / Git Bash
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1   # Windows
```

Add `--update` (shell) or `-Update` (PowerShell) to regenerate `expected.txt`
from the current output. Review the diff before committing: the point of the
files is to fail when behaviour changes unintentionally.

## Case layout

| File | Purpose |
|---|---|
| `input.json` | stdin for the status line. Required. `{HOME}` and `{DIR}` are replaced with sandbox paths, always written with forward slashes so one expected file serves both runners. |
| `cache.json` | `.cc-status-lite-cache.json` fixture. Optional. |
| `expected.txt` | Exact expected output. `\e` stands in for the ESC byte. |
| `expected.re` | Regular expression, used instead of `expected.txt`. |
| `opts` | `key=value` lines. `cache_age=<seconds>` backdates the cache to exercise the stale path. |

## Why some cases use a regular expression

`resets_at` is stored in UTC and rendered in local time. The shell runner could
pin `TZ`, but PowerShell resolves the local time zone from the OS and cannot be
overridden per process. Cases that carry a real timestamp therefore assert the
*shape* of the rendered time (`10-reset-time`), while every case that checks
colours, thresholds, layout and number formatting sets `resets_at` to `null` so
its expectation is identical everywhere.

## Windows path handling

`{HOME}` and `{DIR}` are substituted as forward-slash paths on every platform,
so the status line abbreviates them to `~/work` identically under both runners.
Backslash input - what Claude Code actually hands the status line on Windows -
is covered by `12-windows-path`, which passes a literal `C:\Program Files\demo`
and expects it back unchanged. That case is platform-independent: both
implementations normalise to forward slashes internally and restore backslashes
on output, so it runs the same on macOS.

## What the runners guarantee

Each case runs in a throwaway sandbox with `HOME`/`USERPROFILE` and
`CLAUDE_CONFIG_DIR` redirected, so `~` abbreviation is exercised and no real
repository is in scope for the branch lookup. A fresh cache stamp is written
before every run, which keeps the background refresh from firing: **the tests
never reach the network and never read your credentials.**
