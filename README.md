# statusline-pro

Claude Code 상태줄에 컨텍스트 사용량과 5시간/주간 한도를 두 줄로 표시합니다.

```
[Opus 5] ~/my-project (main)
🧠 32% (64k/200k)  ⏳ 5h 21%  📅 7d 30%
```

- 🧠 컨텍스트 사용률, 사용 토큰 / 최대 (1M 컨텍스트 모델도 지원)
- ⏳ 5시간 한도, 📅 주간 한도
- 색상 임계치: 70% 노랑, 90% 빨강
- Windows(Git Bash) / macOS / Linux 공용

## 설치

`~/.claude/skills/` 아래에 두면 별도 설치 과정 없이 다음 세션에 자동으로 로드됩니다.

```bash
git clone <저장소 주소> ~/.claude/skills/statusline-pro
```

Claude Code 를 재시작한 뒤:

```
/statusline-install
```

업데이트는 `git pull` 후 `/statusline-install` 재실행.

제거: `/statusline-uninstall` (이전 상태줄이 있었다면 복원됩니다)

### 왜 `/statusline-install` 이 따로 필요한가

**플러그인은 메인 `statusLine` 키를 설정할 수 없습니다.**
[공식 문서](https://code.claude.com/docs/en/plugins-reference)상 플러그인 `settings.json` 은 `agent` 와
`subagentStatusLine` 만 지원합니다. 그래서 사용자 `settings.json` 에 한 번 쓰는 단계가 필요하고,
그 작업을 스크립트로 자동화한 것이 이 명령입니다.

### 마켓플레이스로 배포할 경우

`.claude-plugin/marketplace.json` 이 포함되어 있어 공개 저장소로 올리면 그대로 마켓플레이스가 됩니다.

```
/plugin marketplace add <owner>/<repo>
/plugin install statusline-pro@statusline-pro
/statusline-install
```

단, **private 저장소 + HTTPS 조합에서는 백그라운드 자동 업데이트가 실패할 수 있습니다**
(공식 문서: 백그라운드 `git pull` 이 git credential helper 를 비활성화함).
개인용으로 여러 PC 에서 쓸 때는 위의 `git clone` 방식을 권장합니다.

## 요구사항

`jq` 만 별도 설치가 필요합니다.

| OS | 명령 |
|---|---|
| macOS | `brew install jq` |
| Windows | `winget install jqlang.jq` |
| Linux | `sudo apt install jq` |

나머지(`bash` `curl` `git` `awk` `stat` `date`)는 각 OS 기본 제공이거나 Git for Windows 에 포함되어 있습니다.

## 인증

**별도 로그인이 필요 없습니다.** 이미 로그인된 Claude Code 자격증명을 그대로 씁니다.

- macOS: 키체인 (`security find-generic-password -s 'Claude Code-credentials'`)
- Windows / Linux: `~/.claude/.credentials.json`

읽은 OAuth 토큰은 **본인 사용량 조회를 위해 `api.anthropic.com/api/oauth/usage` 에만** 전송되며,
그 외 어디에도 저장하거나 보내지 않습니다. 응답은 `~/.claude/.usage-cache.json` 에 캐시됩니다.
토큰 자체는 디스크에 기록되지 않습니다.

`ANTHROPIC_API_KEY` 로만 쓰는 경우 OAuth 자격증명이 없어 5h/7d 는 표시되지 않습니다(나머지는 정상 동작).

## 동작 방식

상태줄은 매 렌더마다 실행되므로 **API 를 동기 호출하지 않습니다.** 캐시 파일만 읽고,
1분 이상 낡았으면 백그라운드 갱신을 던져둡니다. stamp 파일로 중복 요청을 막습니다.

15분 넘게 갱신에 실패해도 값을 숨기지 않고 흐리게(dim) 표시합니다 — 최신이 아님만 드러냅니다.

## 문제 해결

**5h/7d 가 안 보임**

1. 로그인 상태 확인 (`ANTHROPIC_API_KEY` 전용 사용자는 표시되지 않음)
2. 캐시 확인: `cat ~/.claude/.usage-cache.json` — `five_hour.utilization` 이 있어야 함
3. 없으면 강제 갱신 후 재시도:
   ```sh
   rm -f ~/.claude/.usage-cache.json.stamp
   echo '{"model":{"display_name":"T"},"workspace":{"current_dir":"."}}' | sh ~/.claude/statusline-pro.sh
   sleep 3
   echo '{"model":{"display_name":"T"},"workspace":{"current_dir":"."}}' | sh ~/.claude/statusline-pro.sh
   ```

**macOS 에서 `CLAUDE_CONFIG_DIR` 를 쓰는 경우** 5h/7d 가 표시되지 않습니다.
그 조합에서는 키체인 서비스명이 `Claude Code-credentials-<sha256 앞 8자>` 로 바뀌는데 지원하지 않습니다.
Windows/Linux 는 파일 기반이라 `CLAUDE_CONFIG_DIR` 를 써도 정상입니다.

**아무것도 안 보임** — `jq` 설치 여부를 확인하세요.

## 알려진 제약

- OAuth 토큰 자동 갱신을 하지 않습니다. 만료되면 값이 흐린 상태로 굳고, Claude Code 가 자격증명을 갱신하면 자동 복구됩니다.
- 플러그인을 업데이트해도 `~/.claude/statusline-pro.sh` 는 자동 갱신되지 않습니다. `/statusline-install` 을 다시 실행하세요.

## 라이선스

MIT
