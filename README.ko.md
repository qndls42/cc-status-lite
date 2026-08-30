# cc-status-lite

Claude Code 상태줄을 두 줄로 바꿉니다. 왼쪽은 컨텍스트 사용량, 오른쪽은 5시간·주간
한도이고, 괄호 안은 각 한도가 초기화되는 로컬 시각입니다.

```
[Opus 5] ~/my-project (main)
🧠 32% (64k/200k)  🕐 5h 21% (07/27 19:40)  📅 7d 30% (07/30 08:59)
```

- 🧠 컨텍스트 사용률 - 퍼센트, 사용 토큰, 컨텍스트 창 크기 (1M 모델 포함)
- 🕐 5시간 한도, 📅 주간 한도 - 괄호 안은 초기화되는 로컬 시각
- 70% 노랑, 90% 빨강. 초기화 시각은 평소 흐리게 두다가 70%부터 함께 강조
- 갱신 실패가 15분을 넘으면 값을 숨기지 않고 흐리게 표시 - 계속 보이되 최신이
  아님을 알립니다
- Windows / macOS / Linux 각각 네이티브 구현

[English](README.md)

## 설치

```
/plugin marketplace add qndls42/cc-status-lite
/plugin install cc-status-lite@cc-status-lite
```

Claude Code를 재시작하면 다음 세션에서 Claude가 상태줄을 켤지 먼저 물어봅니다.
직접 실행하려면 언제든:

```
/statuslite-install
```

### 요구사항

| 플랫폼 | 필요한 것 |
|---|---|
| macOS, Linux | `jq`, `curl`, `git` |
| Windows | 추가 설치 불필요 - PowerShell과 `curl.exe`는 Windows 10 1803+ 기본 탑재 |
| Windows + Git Bash | 셸 구현을 쓰고 싶다면 `jq` |

`curl`과 `git`은 대개 이미 있습니다. `jq`가 없으면 설치 스크립트가 플랫폼별 설치
명령을 출력하고 멈춥니다 - 대신 설치해 주지는 않습니다.

## 업데이트

할 일이 없습니다. `/plugin update` 면 충분합니다. SessionStart 훅이 매 세션마다
설치된 사본을 플러그인과 동기화합니다. `git pull` 도 재설치도 필요 없습니다.

## 제거

```
/statuslite-uninstall
```

이전에 쓰던 상태줄이 있었다면 복원하고, 없었다면 키만 제거합니다. `settings.json`
의 나머지는 건드리지 않습니다. 플러그인 자체까지 지우려면
`/plugin uninstall cc-status-lite@cc-status-lite` 를 실행하세요.

## 왜 설치 단계가 따로 필요한가

**플러그인은 메인 `statusLine` 키를 설정할 수 없습니다.**
[플러그인 레퍼런스](https://code.claude.com/docs/en/plugins-reference)상 플러그인
설정은 `agent` 와 `subagentStatusLine` 만 지원합니다. 그래서 사용자
`settings.json` 에 한 번 쓰는 단계를 피할 수 없고, 그 한 번을 손이 아니라
스크립트가 하도록 만든 것이 설치 명령입니다.

여기서 따라오는 두 번째 제약이 있습니다. `${CLAUDE_PLUGIN_ROOT}` 는
`settings.json` 안에서 전개되지 않고, 플러그인 디렉터리는 경로에 버전이 박혀 있어
업데이트마다 바뀝니다. 그래서 `settings.json` 은 설정 디렉터리에 있는 고정 경로의
사본을 가리키고, 그 사본을 최신으로 유지하는 것이 SessionStart 훅입니다.

## 무엇을 읽고 어디로 보내는가

이 플러그인은 Claude 자격증명을 읽습니다. 분명히 밝혀둡니다.

**무엇을 읽는가.** Claude Code 자신의 OAuth 액세스 토큰을 macOS 키체인
(`security find-generic-password -s 'Claude Code-credentials'`) 에서, 다른
플랫폼에서는 `~/.claude/.credentials.json` 에서 읽습니다. 5시간·주간 사용률은
Claude Code가 상태줄에 넘겨주는 데이터에 들어 있지 않아서 직접 조회해야 합니다.

**어디로 보내는가.** `https://api.anthropic.com/api/oauth/usage` 로 요청 한 건.
Claude Code 자신이 쓰는 것과 같은 엔드포인트입니다. URL은 하드코딩이고 환경에서
가져온 값이 끼어들지 않습니다. 다른 네트워크 호출도, 텔레메트리도, 제3자 서비스도
없습니다.

**토큰을 어떻게 다루는가.** 절대 커맨드라인 인자로 넘기지 않습니다. 프로세스 인자는
macOS의 `ps` 와 Linux의 `/proc/<pid>/cmdline` 으로 누구나 읽을 수 있어서, 인자로
넘기면 같은 머신의 다른 로컬 사용자가 - 또는 키체인을 열지 못하는 권한 없는
프로세스가 - 토큰을 가져갈 수 있습니다. 셸 구현은 `curl --config -` 로 헤더를
stdin 으로 전달하고, PowerShell 구현은 메모리에만 둡니다. 토큰은 디스크에 쓰이지
않으며, 이 플러그인은 토큰을 갱신하거나 저장하지 않습니다.

**무엇을 쓰는가.** `~/.claude/.cc-status-lite-cache.json`, 권한 `600`, 네 개 필드만
(5시간·주간의 `utilization` 과 `resets_at`). API 응답에는 지출액과 크레딧 잔액도
들어 있지만 상태줄이 표시하지 않으므로 캐시하지 않고 버립니다.

**설정에서 무엇을 바꾸는가.** `statusLine` 키 하나. 설치 스크립트가 먼저
`settings.json` 을 백업하고, 덮어쓴 기존 상태줄을 기록해 두어 제거할 때 되돌립니다.

**하지 않는 것.** 토큰 갱신, 자격증명 기록, `api.anthropic.com` 외 호스트 호출,
데이터 외부 전송 - 어느 것도 하지 않습니다.

위 내용은 전부 `scripts/statusline.sh` (또는 `scripts/statusline.ps1`) 의 몇 줄에
불과합니다. 설치 전에 통째로 읽을 수 있는 분량이고, 먼저 읽어보는 쪽이 옳습니다.

## 문제 해결

**5h/7d 값이 안 보입니다.** 첫 갱신에 최대 1분 걸립니다. 그 뒤에도 없으면
`~/.claude/.cc-status-lite-cache.json` 이 있는지 보세요. 없으면 토큰 조회가 실패한 것이니
Claude Code에서 다시 로그인하고 새 세션을 시작하세요.

**보이는데 계속 흐립니다.** 흐린 표시는 15분 넘게 갱신에 성공하지 못했다는 뜻이고,
대개 토큰 만료입니다. Claude Code가 자격증명을 갱신하면 다음 호출에서 복구됩니다.

**아무것도 안 보입니다.** `~/.claude/settings.json` 의 `statusLine` 이
`cc-status-lite` 를 가리키는지 확인하고, 스크립트를 직접 실행해 보세요:

```bash
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$HOME"'"},"context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000}}' \
  | bash ~/.claude/cc-status-lite.sh
```

**Windows에서 `bad interpreter: /bin/sh^M`.** 스크립트가 CRLF로 체크아웃된
경우입니다. `.gitattributes` 가 LF로 고정하고 있으니 다시 clone 하거나,
`git config core.autocrlf false` 후 다시 체크아웃하세요.

**`/statuslite-install` 이 두 번 나옵니다.** 예전 수동 clone이
`~/.claude/skills/cc-status-lite` 에 남아 있습니다. 플러그인이 대체하므로 지우면
됩니다.

## 개발

```bash
sh tests/run-tests.sh                                                    # macOS, Linux, Git Bash
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1   # Windows
```

두 러너가 `tests/cases/` 의 같은 케이스를 읽으므로 셸 구현과 PowerShell 구현이 한
가지 기준으로 검증됩니다. 케이스를 추가하기 전에
[tests/README.md](tests/README.md) 를 보세요.

## 라이선스

MIT. [LICENSE](LICENSE) 참고.
