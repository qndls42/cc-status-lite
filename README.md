# cc-status-lite

A two-line Claude Code status line: context usage on the left, your 5-hour and
weekly limits on the right, each with the local time it resets.

```
[Opus 5] ~/my-project (main)
🧠 32% (64k/200k)  ⏳ 5h 21% (07/27 19:40)  📅 7d 30% (07/30 08:59)
```

- 🧠 context usage - percentage, tokens used, context window size (1M models included)
- ⏳ 5-hour limit and 📅 weekly limit, with the local time each resets in brackets
- Yellow at 70%, red at 90%. The reset time stays dim until the percentage hits
  70%, then takes the same colour
- If a refresh fails for more than 15 minutes the values are dimmed rather than
  hidden - still visible, marked as no longer current
- Windows, macOS and Linux, with a native implementation for each

[한국어 문서](README.ko.md)

## Install

```
/plugin marketplace add qndls42/cc-status-lite
/plugin install cc-status-lite@cc-status-lite
```

Restart Claude Code. On the next session Claude offers to turn the status line
on; accept and it is done. To do it yourself at any time:

```
/statuslite-install
```

### Requirements

| Platform | Needs |
|---|---|
| macOS, Linux | `jq`, `curl`, `git` |
| Windows | nothing extra - PowerShell and `curl.exe` ship with Windows 10 1803+ |
| Windows with Git Bash | `jq` if you prefer the shell implementation |

`curl` and `git` are almost always already present. If `jq` is missing the
installer prints the command for your platform and stops - it never installs
anything for you.

## Updating

Nothing to do. `/plugin update` is enough: a `SessionStart` hook keeps the
installed copy in sync with the plugin on every session start. There is no
`git pull` and no reinstall.

## Uninstall

```
/statuslite-uninstall
```

This restores whatever status line you had before, or removes the key if you
had none. It touches nothing else in `settings.json`. To remove the plugin
itself as well, run `/plugin uninstall cc-status-lite@cc-status-lite`.

## Why there is a separate install step

**Plugins cannot set the main `statusLine` key.** The
[plugin reference](https://code.claude.com/docs/en/plugins-reference) allows
only `agent` and `subagentStatusLine` in a plugin's settings, so one write to
your own `settings.json` is unavoidable. The installer is that write, done by a
script instead of by hand.

A second consequence: `${CLAUDE_PLUGIN_ROOT}` is not expanded inside
`settings.json`, and the plugin's own directory carries its version in the path,
so it changes on every update. `settings.json` therefore points at a stable copy
in your config directory, and the `SessionStart` hook is what keeps that copy
current.

## What this reads and sends

This plugin reads your Claude credentials. That is worth stating plainly.

**What it reads.** Claude Code's own OAuth access token, from the macOS keychain
(`security find-generic-password -s 'Claude Code-credentials'`) or, on other
platforms, from `~/.claude/.credentials.json`. Your 5-hour and weekly
utilisation are not part of the data Claude Code hands a status line, so they
have to be requested.

**Where it sends it.** One request, to `https://api.anthropic.com/api/oauth/usage`
- the same endpoint Claude Code itself uses. The URL is hard-coded; nothing from
your environment is interpolated into it. There is no other network call, no
telemetry, and no third-party service.

**How the token is handled.** It is never passed as a command-line argument.
Process arguments are world-readable through `ps` on macOS and
`/proc/<pid>/cmdline` on Linux, so an argument would let any other local user -
or any unprivileged process, without ever unlocking the keychain - read it. The
shell implementation passes the header through `curl --config -` on stdin; the
PowerShell implementation keeps it in memory. The token is never written to
disk, and this plugin never refreshes or stores it.

**What it writes.** `~/.claude/.cc-status-lite-cache.json`, mode `600`, holding four
fields: `utilization` and `resets_at` for the 5-hour and weekly windows. The API
response also carries spend and credit balances; those are discarded rather than
cached, because the status line does not display them.

**What it changes in your settings.** One key, `statusLine`. The installer backs
up `settings.json` first and records any status line it replaces, so the
uninstaller can put it back.

**What it never does.** Refresh tokens, write credentials anywhere, call any
host other than `api.anthropic.com`, or send your data to anyone.

Every claim above is a few lines of `scripts/statusline.sh` (or
`scripts/statusline.ps1`) - both are short enough to read in full before you
install them, and reading them first is the right instinct.

## Troubleshooting

**The 5h/7d values never appear.** The first refresh takes up to a minute. After
that, check that `~/.claude/.cc-status-lite-cache.json` exists. If it does not, the token
lookup failed - sign in again in Claude Code and start a new session.

**They appear but stay dim.** Dim means no successful refresh for 15 minutes,
usually an expired token. Claude Code refreshes credentials on its own; the
values recover on the next successful call.

**Nothing shows at all.** Confirm `statusLine` in `~/.claude/settings.json`
points at `cc-status-lite`, and that the status line runs on its own:

```bash
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$HOME"'"},"context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000}}' \
  | bash ~/.claude/cc-status-lite.sh
```

**`bad interpreter: /bin/sh^M` on Windows.** The scripts were checked out with
CRLF endings. `.gitattributes` pins them to LF; re-clone, or run
`git config core.autocrlf false` and check out again.

**`/statuslite-install` appears twice.** An older manual clone is still in
`~/.claude/skills/cc-status-lite`. Delete it - the plugin supersedes it.

## Development

```bash
sh tests/run-tests.sh                                                    # macOS, Linux, Git Bash
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1   # Windows
```

Both runners read the same cases from `tests/cases/`, so the shell and
PowerShell implementations are held to one set of expectations. See
[tests/README.md](tests/README.md) before adding a case.

## License

MIT. See [LICENSE](LICENSE).
