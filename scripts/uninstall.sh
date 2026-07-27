#!/bin/sh
# statusline-pro 제거: settings.json 의 statusLine 을 되돌리고 복사본을 지운다.
set -e

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"
prevfile="$cfg/.statusline-pro-previous"

[ -f "$settings" ] || { echo "$settings 없음. 할 일 없음."; exit 0; }

cur=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)
case "$cur" in
  *statusline-pro*) ;;
  *) echo "현재 statusLine 은 statusline-pro 가 아닙니다: ${cur:-(없음)}"; echo "건드리지 않고 종료합니다."; exit 0 ;;
esac

tmp="$settings.tmp.$$"
if [ -f "$prevfile" ]; then
  prev=$(cat "$prevfile")
  jq --arg c "$prev" '.statusLine = {"type": "command", "command": $c}' "$settings" > "$tmp"
  echo "이전 statusLine 으로 복원: $prev"
  rm -f "$prevfile"
else
  jq 'del(.statusLine)' "$settings" > "$tmp"
  echo "statusLine 키를 제거했습니다."
fi
mv -f "$tmp" "$settings"

rm -f "$cfg/statusline-pro.sh" "$cfg/.usage-cache.json" "$cfg/.usage-cache.json.stamp" "$cfg/.usage-cache.json.tmp"
echo "제거 완료. 새 세션부터 반영됩니다."
