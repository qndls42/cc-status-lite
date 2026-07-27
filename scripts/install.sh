#!/bin/sh
# statusline-pro 설치: 스크립트를 설정 디렉터리로 복사하고 settings.json 에 statusLine 키를 쓴다.
# 플러그인은 메인 statusLine 키를 직접 설정할 수 없어(공식 문서: agent / subagentStatusLine 만 지원)
# 이 한 번의 쓰기가 반드시 필요하다.
set -e

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dest="$cfg/statusline-pro.sh"
settings="$cfg/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq 가 필요합니다."
  echo "  macOS   : brew install jq"
  echo "  Windows : winget install jqlang.jq"
  echo "  Linux   : sudo apt install jq"
  exit 1
fi

mkdir -p "$cfg"
cp "$root/scripts/statusline.sh" "$dest"
chmod +x "$dest" 2>/dev/null || true

[ -f "$settings" ] || printf '{}\n' > "$settings"

# settings.json 이 깨져 있으면 건드리지 않는다
if ! jq -e . "$settings" >/dev/null 2>&1; then
  echo "ERROR: $settings 를 JSON 으로 읽을 수 없습니다. 수동 확인이 필요합니다."
  exit 1
fi

# 우리 것이 아닌 기존 statusLine 은 되돌릴 수 있게 보관
prev=$(jq -r '.statusLine.command // empty' "$settings")
case "$prev" in
  ''|*statusline-pro*) ;;
  *)
    printf '%s\n' "$prev" > "$cfg/.statusline-pro-previous"
    echo "기존 statusLine 을 백업했습니다: $prev"
    ;;
esac

# 기본 설정 디렉터리면 ~ 표기(검증된 형태), 커스텀이면 절대경로
case "$cfg" in
  "$HOME/.claude") cmd='bash ~/.claude/statusline-pro.sh' ;;
  *) cmd="bash \"$dest\"" ;;
esac

cp "$settings" "$settings.bak.statusline-pro"
tmp="$settings.tmp.$$"
jq --arg c "$cmd" '.statusLine = {"type": "command", "command": $c}' "$settings" > "$tmp"
mv -f "$tmp" "$settings"

echo "설치 완료"
echo "  스크립트 : $dest"
echo "  설정     : $settings  (백업: $settings.bak.statusline-pro)"
echo "  명령     : $cmd"
echo
echo "동작 확인:"
printf '{"model":{"display_name":"Test"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000}}\n' "$HOME" \
  | sh "$dest" || true
echo
echo "5h/7d 는 첫 갱신까지 최대 1분 걸립니다. 새 세션부터 상태줄에 반영됩니다."
