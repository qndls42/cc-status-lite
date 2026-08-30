#!/bin/sh
# Shared-case test runner for the shell implementation.
# The PowerShell runner (run-tests.ps1) reads the same tests/cases/ directory,
# so both implementations are held to one set of expectations.
#
#   sh tests/run-tests.sh            run every case
#   sh tests/run-tests.sh --update   rewrite expected.txt from actual output
#
# Each case directory may contain:
#   input.json     stdin for the status line (required)
#   cache.json     a .cc-status-lite-cache.json fixture (optional)
#   expected.txt   exact expected output, with \e standing in for ESC
#   expected.re    an extended regular expression, used instead of expected.txt
#   opts           key=value lines; cache_age=<seconds> backdates cache.json
#
# Placeholders substituted in input.json: {HOME}, {DIR}
set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script="$root/scripts/statusline.sh"
update=""
[ "${1:-}" = "--update" ] && update=1

ESC=$(printf '\033')
pass=0
fail=0
updated=0

for case_dir in "$root"/tests/cases/*/; do
  name=$(basename "$case_dir")
  [ -f "$case_dir/input.json" ] || continue

  # A fresh sandbox per case: HOME is redirected so ~ abbreviation is testable
  # and no real repository is ever in scope for the branch lookup.
  sandbox=$(mktemp -d 2>/dev/null || mktemp -d -t cc-status-lite)
  mkdir -p "$sandbox/work" "$sandbox/.claude"

  cache_age=0
  [ -f "$case_dir/opts" ] && . "$case_dir/opts"

  if [ -f "$case_dir/cache.json" ]; then
    cp "$case_dir/cache.json" "$sandbox/.claude/.cc-status-lite-cache.json"
    if [ "$cache_age" -gt 0 ]; then
      # Backdate the cache to exercise the stale path. touch -t needs a
      # timestamp; compute it with the same date command on both BSD and GNU.
      ts=$(date -v-"${cache_age}"S '+%Y%m%d%H%M.%S' 2>/dev/null \
           || date -d "@$(( $(date +%s) - cache_age ))" '+%Y%m%d%H%M.%S' 2>/dev/null)
      [ -n "$ts" ] && touch -t "$ts" "$sandbox/.claude/.cc-status-lite-cache.json"
    fi
  fi
  # A fresh stamp keeps the background refresh from firing: tests must never
  # reach the network.
  : > "$sandbox/.claude/.cc-status-lite-cache.json.stamp"

  input=$(sed -e "s|{HOME}|$sandbox|g" -e "s|{DIR}|$sandbox/work|g" "$case_dir/input.json")

  actual=$(printf '%s' "$input" | HOME="$sandbox" USERPROFILE="$sandbox" \
           CLAUDE_CONFIG_DIR="$sandbox/.claude" sh "$script")
  actual_esc=$(printf '%s' "$actual" | sed "s/$ESC/\\\\e/g")

  rm -rf "$sandbox"

  if [ -f "$case_dir/expected.re" ]; then
    if printf '%s' "$actual_esc" | grep -qE "$(cat "$case_dir/expected.re")"; then
      pass=$((pass + 1)); echo "  ok    $name"
    else
      fail=$((fail + 1)); echo "  FAIL  $name"
      echo "        expected to match: $(cat "$case_dir/expected.re")"
      echo "        actual:            $actual_esc"
    fi
    continue
  fi

  if [ -n "$update" ]; then
    printf '%s\n' "$actual_esc" > "$case_dir/expected.txt"
    echo "  wrote $name"
    updated=$((updated + 1))
    continue
  fi

  expected=$(cat "$case_dir/expected.txt" 2>/dev/null)
  if [ "$actual_esc" = "$expected" ]; then
    pass=$((pass + 1)); echo "  ok    $name"
  else
    fail=$((fail + 1)); echo "  FAIL  $name"
    echo "        expected: $expected"
    echo "        actual:   $actual_esc"
  fi
done

echo
# In update mode most cases are rewritten rather than compared, so reporting
# them as "passed" would be misleading - only the regex cases are still checked.
if [ -n "$update" ]; then
  echo "$updated updated, $pass verified by pattern, $fail failed"
else
  echo "$pass passed, $fail failed"
fi
[ "$fail" -eq 0 ]
