#!/bin/sh
# Claude Code statusline — Windows(Git Bash) / macOS / Linux 공용
input=$(cat)

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# jq 한 번으로 필요한 값 전부 추출 (statusline은 매 렌더마다 실행되므로 프로세스 최소화)
{ read -r model; read -r dir; read -r cpct; read -r ctok; } <<EOF
$(printf '%s' "$input" | jq -r '
  def hum: if . >= 1000000 then "\((. / 100000 | round) / 10)M"
           elif . >= 1000 then "\(. / 1000 | round)k"
           else tostring end;
  (.model.display_name // "?"),
  (.workspace.current_dir // .cwd // "."),
  (.context_window.used_percentage as $p | if $p == null then "" else ($p | round | tostring) end),
  (if .context_window.used_percentage == null then ""
   else "\(.context_window.total_input_tokens // 0 | hum)/\(.context_window.context_window_size // 0 | hum)"
   end)
' | tr -d '\r')
EOF

# 홈 디렉터리를 ~ 로 축약.
# Windows는 current_dir이 C:\... 이고 홈이 $USERPROFILE, 유닉스는 $HOME 이라 둘 다 시도한다.
# 일단 / 로 통일해 비교하고, 원래 경로가 백슬래시였으면 되돌린다.
case "$dir" in *\\*) win=1 ;; *) win="" ;; esac
nd=$(printf '%s' "$dir" | tr '\\' '/')
disp="$nd"
for h in "$USERPROFILE" "$HOME"; do
  [ -z "$h" ] && continue
  nh=$(printf '%s' "$h" | tr '\\' '/')
  case "$nd" in
    "$nh") disp="~"; break ;;
    "$nh"/*) disp="~${nd#"$nh"}"; break ;;
  esac
done
[ -n "$win" ] && disp=$(printf '%s' "$disp" | tr '/' '\\')

# git 저장소일 때만 브랜치 표시 (optional lock 생략)
branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

# 파일 나이(초). 파일이 없으면 아주 큰 값.
# 주의: find 는 쓰지 말 것 — Claude Code 실행 PATH에서 Windows의 find.exe 가 GNU find 를 가린다.
# stat 은 GNU(-c) / BSD(-f) 문법이 달라 둘 다 시도한다.
now=$(date +%s)
age() {
  m=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null)
  [ -z "$m" ] && m=0
  AGE=$((now - m))
}

# 5시간/주간 사용량: stdin에 없어 OAuth API 호출이 필요.
# statusline은 매 렌더 실행되므로 절대 블로킹하지 않는다 —
# 캐시 파일만 읽고, 1분 이상 낡았으면 백그라운드로 갱신을 던져둔다.
uc="$cfg/.usage-cache.json"
age "$uc.stamp"
if [ "$AGE" -ge 60 ]; then
  : > "$uc.stamp"   # 먼저 찍어 중복 fetch 방지
  (
    # 토큰: macOS는 키체인, 그 외는 .credentials.json
    # ponytail: CLAUDE_CONFIG_DIR 를 쓰면 키체인 서비스명이 "...-<해시>" 가 된다(OMC 참고).
    #           그 조합은 지원 안 함 — 필요해지면 sha256 앞 8자 해시를 붙일 것.
    tok=""
    if [ "$(uname -s)" = Darwin ]; then
      raw=$(security find-generic-password -s 'Claude Code-credentials' -a "$USER" -w 2>/dev/null \
            || security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null)
      tok=$(printf '%s' "$raw" | jq -r '(.claudeAiOauth // .).accessToken // empty' 2>/dev/null)
    fi
    [ -z "$tok" ] && tok=$(jq -r '(.claudeAiOauth // .).accessToken // empty' \
                           "$cfg/.credentials.json" 2>/dev/null | tr -d '\r')
    # ponytail: 토큰 갱신은 안 함 — 만료되면 값이 흐리게(stale) 굳는다.
    # Claude Code가 자격증명을 갱신하면 자동 복구. 계속 흐리면 refresh_token 흐름 추가.
    [ -n "$tok" ] && curl -sf --max-time 10 \
      -H "Authorization: Bearer $tok" \
      -H "anthropic-beta: oauth-2025-04-20" \
      https://api.anthropic.com/api/oauth/usage > "$uc.tmp" &&
      mv -f "$uc.tmp" "$uc"
  ) >/dev/null 2>&1 &
fi

h5=""; d7=""
age "$uc"; cache_age=$AGE
if [ -f "$uc" ]; then
  { read -r h5; read -r d7; } <<EOF
$(jq -r '
  (.five_hour.utilization as $x | if $x == null then "" else ($x | round | tostring) end),
  (.seven_day.utilization as $x | if $x == null then "" else ($x | round | tostring) end)
' "$uc" 2>/dev/null | tr -d '\r')
EOF
fi

e=$(printf '\033')
GREEN="$e[32m"; YELLOW="$e[33m"; RED="$e[31m"; DIM="$e[2m"; RESET="$e[0m"
# 임계치별 색상 (공식 문서 예시와 동일: 70% 경고 / 90% 위험). 서브셸 없이 $C 설정
stale=""
c_of() {
  if [ -n "$stale" ]; then C=$DIM
  elif [ "$1" -ge 90 ]; then C=$RED
  elif [ "$1" -ge 70 ]; then C=$YELLOW
  else C=$GREEN; fi
}

line1="[$model] $disp"
[ -n "$branch" ] && line1="$line1 ($branch)"

line2=""
[ -n "$cpct" ] && { c_of "$cpct"; line2="🧠 $C$cpct%$RESET $DIM($ctok)$RESET"; }
# 15분 넘게 갱신 실패하면 숨기지 않고 흐리게 — 값은 계속 보이되 최신이 아님을 표시
[ "$cache_age" -ge 900 ] && stale=1
[ -n "$h5" ] && { c_of "$h5"; line2="$line2  ⏳ 5h $C$h5%$RESET"; }
[ -n "$d7" ] && { c_of "$d7"; line2="$line2  📅 7d $C$d7%$RESET"; }

printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"
exit 0
