<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/example-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/example-light.svg">
    <img alt="cc-status-lite 를 적용한 Claude Code 화면. 첫 줄에 모델과 경로, 둘째 줄에 컨텍스트 사용량과 5시간·주간 한도가 초기화 시각과 함께 표시됩니다." src="assets/example-light.svg" width="760">
  </picture>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <a href="https://github.com/qndls42/cc-status-lite/tags"><img alt="Version" src="https://img.shields.io/github/v/tag/qndls42/cc-status-lite?label=version"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%20%C2%B7%20Linux%20%C2%B7%20Windows-lightgrey">
  <a href="README.md"><img alt="English" src="https://img.shields.io/badge/README-English-lightgrey"></a>
</p>

# 얼마나 남았는지, Claude Code 를 벗어나지 않고

터미널 아래 두 줄. 왼쪽은 컨텍스트 사용량, 오른쪽은 5시간·주간 한도이고, 괄호 안은 각 한도가 초기화되는 로컬 시각입니다.

Claude Code 는 상태줄에 컨텍스트 사용량은 알려주지만 **한도는 알려주지 않습니다.** 정작 "작업 하나 더 시작해도 되나"를 결정할 때 보고 싶은 건 그 숫자입니다. cc-status-lite 는 Claude Code 자신이 쓰는 것과 같은 엔드포인트에서 그 값을 가져와 1분간 캐시하고, 터미널을 한 번도 붙잡지 않고 그려냅니다.

구현은 둘, 동작은 하나입니다. macOS·Linux 용 POSIX 셸 스크립트와 Windows 네이티브 PowerShell 스크립트가 같은 테스트 케이스로 검증됩니다.

## 설치

명령 세 줄. 앞의 둘은 Claude Code 안에서 실행합니다.

### 1. 마켓플레이스 등록

```
/plugin marketplace add qndls42/cc-status-lite
```

### 2. 플러그인 설치

```
/plugin install cc-status-lite@cc-status-lite
```

### 3. 상태줄 켜기

Claude Code 를 재시작하면 다음 세션에서 Claude 가 켤지 물어봅니다. 예라고 하면 끝입니다.

직접 실행하려면:

```
/statuslite-install
```

> [!TIP]
> 두 줄이 뜨고, 퍼센트에 색이 들어가고, 1분 안에 5h/7d 값이 나타나면 정상입니다. 첫 줄만 뜨고 둘째 줄이 없으면 플러그인은 깔렸지만 상태줄이 안 켜진 것이니 `/statuslite-install` 을 실행하세요.

### 요구사항

| 플랫폼 | 필요한 것 |
|---|---|
| **macOS · Linux** | `jq`, `curl`, `git` |
| **Windows** | 없음 |

<details>
<summary><strong>macOS · Linux</strong> — <code>jq</code> 설치</summary>

<br>

`curl` 과 `git` 은 대개 이미 있습니다. `jq` 가 없으면 설치 스크립트가 플랫폼별 명령을 출력하고 멈춥니다 — 대신 설치해 주지는 않습니다.

```bash
brew install jq          # macOS
sudo apt install jq      # Debian, Ubuntu
sudo dnf install jq      # Fedora
```

</details>

<details>
<summary><strong>Windows</strong> — 추가 설치가 없는 이유</summary>

<br>

Windows 는 별도의 PowerShell 구현을 씁니다. PowerShell 과 `curl.exe` 는 Windows 10 1803 이상에 기본 탑재이고 `ConvertFrom-Json` 도 내장이라, Git Bash 도 `jq` 도 필요 없습니다.

Git Bash 와 `jq` 가 이미 있다면 clone 에서 `scripts/install.sh` 를 실행해 셸 구현을 쓸 수도 있습니다. 출력은 동일하며, 아무것도 설치할 필요가 없다는 이유로 PowerShell 쪽이 기본입니다.

알아둘 것이 하나 있습니다. Windows 기본 `PATH` 의 `bash` 는 Git Bash 가 아니라 **WSL 실행 스텁**인 경우가 대부분입니다. 셸 구현을 쓰시려면 Git Bash 를 전체 경로로 부르세요 — 보통 `C:\Program Files\Git\bin\bash.exe` 입니다.

</details>

## 상태줄 읽는 법

```
[Opus 5] ~/my-project (main)
🧠 32% (64k/200k)  🕐 5h 21% (08/31 14:49)  📅 7d 46% (09/03 17:59)
```

| 구간 | 의미 |
|---|---|
| `[Opus 5]` | 이 세션이 쓰는 모델 |
| `~/my-project (main)` | 작업 디렉터리(홈은 `~` 로 축약)와, 저장소라면 git 브랜치 |
| 🧠 `32% (64k/200k)` | 컨텍스트 사용률, 사용 토큰, 컨텍스트 창 크기 |
| 🕐 `5h 21% (08/31 14:49)` | 5시간 한도와 초기화되는 로컬 시각 |
| 📅 `7d 46% (09/03 17:59)` | 주간 한도와 초기화되는 로컬 시각 |

색이 긴급도를 담고 있어서, 읽지 않아도 읽힙니다.

| | 퍼센트 | 초기화 시각 |
|---|---|---|
| **70% 미만** | 초록 | 흐리게 |
| **70% 이상** | 노랑 | 노랑 |
| **90% 이상** | 빨강 | 빨강 |
| **오래됨** | 흐리게 | 흐리게 |

*오래됨*은 15분 넘게 갱신에 성공하지 못했다는 뜻이고, 대개 토큰 만료입니다. Claude Code 가 알아서 갱신하므로 값을 숨기지 않고 흐리게 두어 최신이 아님을 알립니다.

## 왜 이렇게 만들었나

### #1 한도는 상태줄이 받는 데이터에 없다

**문제.** Claude Code 는 상태줄에 모델, 작업 디렉터리, 컨텍스트 창을 넘겨줍니다. 5시간·주간 사용률은 그 안에 없는데, 정작 작업을 하나 더 시작할지 결정하는 건 그 숫자입니다.

**해결.** `https://api.anthropic.com/api/oauth/usage` 에 인증 요청 한 건. Claude Code 자신이 쓰는 것과 같은 엔드포인트입니다. 1분 캐시하고 분리된 백그라운드 프로세스에서 갱신하므로 렌더링이 네트워크를 기다리지 않습니다. 갱신에 실패하면 마지막 값을 버리지 않고 흐리게 표시합니다.

### #2 플러그인은 상태줄을 설정할 수 없다

**문제.** [플러그인 레퍼런스](https://code.claude.com/docs/en/plugins-reference)상 플러그인 설정은 `agent` 와 `subagentStatusLine` 만 허용하고 메인 `statusLine` 은 안 됩니다. 게다가 `${CLAUDE_PLUGIN_ROOT}` 는 `settings.json` 안에서 전개되지 않는데, 플러그인 디렉터리는 경로에 버전이 박혀 있어 업데이트마다 바뀝니다.

**해결.** 사용자 `settings.json` 에 한 번만 쓰되, 설정 디렉터리의 고정 경로를 가리킵니다. 그다음부터는 `SessionStart` 훅이 매 세션 그 사본을 플러그인 원본과 비교해 다르면 갱신합니다. `/plugin update` 면 충분하고, `git pull` 도 재설치도 없습니다.

### #3 Windows 는 곁다리가 아니다

**문제.** Windows 에서 셸 스크립트를 쓴다는 건 Git Bash 와 `jq` 를 요구한다는 뜻이고, 30초면 까는 도구에 그건 진짜 장벽입니다.

**해결.** 껍데기가 아니라 네이티브 PowerShell 구현. 두 구현이 [`tests/cases/`](tests/cases) 의 같은 케이스를 두 러너로 검증받아 조용히 어긋날 수 없게 했습니다. 이 과정에서 macOS 로는 **원리적으로 드러날 수 없는** 결함들이 나왔습니다 — `[char]` 로 아스트랄 평면 이모지가 조용히 사라지는 문제, .NET 날짜 형식의 `/` 가 로케일의 날짜 구분자로 해석되는 문제, 파일 읽기가 시스템 ANSI 코드페이지로 기본 동작하는 문제.

## 무엇을 읽고 어디로 보내는가

이 플러그인은 Claude 자격증명을 읽습니다. 분명히 밝혀둡니다.

**무엇을 읽는가.** Claude Code 자신의 OAuth 액세스 토큰을 macOS 키체인(`security find-generic-password -s 'Claude Code-credentials'`)에서, 다른 플랫폼에서는 `~/.claude/.credentials.json` 에서 읽습니다.

**어디로 보내는가.** `https://api.anthropic.com/api/oauth/usage` 로 요청 한 건. URL 은 하드코딩이고 환경에서 가져온 값이 끼어들지 않습니다. 다른 네트워크 호출도, 텔레메트리도, 제3자도 없습니다.

**토큰을 어떻게 다루는가.** 절대 커맨드라인 인자로 넘기지 않습니다. 프로세스 인자는 macOS 의 `ps`, Linux 의 `/proc/<pid>/cmdline` 으로 누구나 읽을 수 있어서, 인자로 넘기면 같은 머신의 다른 로컬 사용자가 — 또는 키체인을 열지 못하는 권한 없는 프로세스가 — 토큰을 가져갈 수 있습니다. 셸 구현은 `curl --config -` 로 헤더를 stdin 에 전달하고, PowerShell 구현은 메모리에만 둡니다. 토큰은 디스크에 쓰이지 않으며, 이 플러그인은 토큰을 갱신하거나 저장하지 않습니다.

**무엇을 쓰는가.** `~/.claude/.cc-status-lite-cache.json`, 권한 `600`, 네 개 필드만(5시간·주간의 `utilization` 과 `resets_at`). API 응답에는 지출액과 크레딧 잔액도 들어 있지만 상태줄이 표시하지 않으므로 캐시하지 않고 버립니다.

**설정에서 무엇을 바꾸는가.** `statusLine` 키 하나. 설치 스크립트가 먼저 `settings.json` 을 백업하고, 덮어쓴 기존 상태줄을 기록해 두어 제거할 때 되돌립니다.

**하지 않는 것.** 토큰 갱신, 자격증명 기록, `api.anthropic.com` 외 호스트 호출, 데이터 외부 전송 — 어느 것도 하지 않습니다.

위 내용은 전부 [`scripts/statusline.sh`](scripts/statusline.sh) 또는 [`scripts/statusline.ps1`](scripts/statusline.ps1) 의 몇 줄에 불과합니다. 설치 전에 통째로 읽을 수 있는 분량이고, 먼저 읽어보는 쪽이 옳습니다.

## 업데이트

```
/plugin update cc-status-lite@cc-status-lite
```

이게 전부입니다. `SessionStart` 훅이 다음 세션에서 설치된 사본을 동기화합니다.

## 제거

```
/statuslite-uninstall
```

이전에 쓰던 상태줄이 있었다면 복원하고, 없었다면 키만 제거합니다. `settings.json` 의 나머지는 건드리지 않습니다. 플러그인까지 지우려면:

```
/plugin uninstall cc-status-lite@cc-status-lite
```

## 저장소 구성

| 경로 | 내용 |
|---|---|
| [`scripts/statusline.sh`](scripts/statusline.sh) · [`.ps1`](scripts/statusline.ps1) | 상태줄 본체, 플랫폼별 구현 |
| [`scripts/install.sh`](scripts/install.sh) · [`.ps1`](scripts/install.ps1) | `statusLine` 키 설정, 기존 값 백업 |
| [`scripts/uninstall.sh`](scripts/uninstall.sh) · [`.ps1`](scripts/uninstall.ps1) | 복원 및 파일 정리 |
| [`scripts/json-format.ps1`](scripts/json-format.ps1) | PowerShell 이 `settings.json` 전체를 재작성하지 않게 함 |
| [`hooks/`](hooks) | 설치본을 최신으로 유지하는 `SessionStart` 훅 |
| [`skills/`](skills) | `/statuslite-install`, `/statuslite-uninstall` |
| [`tests/`](tests) | 공유 케이스와 구현별 러너 |

### 동작 요약

| 항목 | 규칙 |
|---|---|
| 갱신 주기 | 최대 1분에 한 번, 분리된 프로세스에서 |
| 블로킹 | 없음 — 렌더링은 캐시만 읽음 |
| 오래됨 판정 | 갱신 성공 없이 15분 |
| 색상 임계치 | 70% 노랑, 90% 빨강 |
| 초기화 시각 | API 가 주는 UTC 를 로컬 시각으로 변환 |
| 캐시 | 네 개 필드, 권한 `600` |
| 설정 쓰기 | 백업 후 `statusLine` 키 하나 |
| 업데이트 | `SessionStart` 훅이 사본 동기화, 재설치 불필요 |

## 문제 해결

**5h/7d 값이 안 보입니다.** 첫 갱신에 최대 1분 걸립니다. 그 뒤에도 없으면 `~/.claude/.cc-status-lite-cache.json` 이 있는지 보세요. 없으면 토큰 조회가 실패한 것이니 Claude Code 에서 다시 로그인하고 새 세션을 시작하세요.

**보이는데 계속 흐립니다.** 15분 넘게 갱신에 성공하지 못했다는 뜻이고 대개 토큰 만료입니다. Claude Code 가 자격증명을 갱신하면 다음 호출에서 복구됩니다.

**아무것도 안 보입니다.** `~/.claude/settings.json` 의 `statusLine` 이 `cc-status-lite` 를 가리키는지 확인하고, 스크립트를 직접 실행해 보세요:

```bash
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$HOME"'"},"context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000}}' \
  | bash ~/.claude/cc-status-lite.sh
```

**Windows 에서 `bad interpreter: /bin/sh^M`.** 스크립트가 CRLF 로 체크아웃된 경우입니다. `.gitattributes` 가 LF 로 고정하고 있으니 다시 clone 하거나, `git config core.autocrlf false` 후 다시 체크아웃하세요.

**`/statuslite-install` 이 두 번 나옵니다.** 예전 수동 clone 이 `~/.claude/skills/` 에 남아 있습니다. 플러그인이 대체하므로 지우면 됩니다.

## 자주 묻는 질문

**터미널이 느려지지 않나요?**
아닙니다. 렌더링은 캐시 파일만 읽습니다. 네트워크 호출은 분리된 백그라운드 프로세스에서 최대 1분에 한 번 일어나고, 상태줄은 그것을 기다리지 않습니다.

**왜 자격증명이 필요한가요?**
한도 사용률이 Claude Code 가 상태줄에 넘겨주는 데이터에 없기 때문입니다. 직접 조회해야 하고, 그 조회는 본인 계정으로 인증돼야 합니다. [무엇을 읽고 어디로 보내는가](#무엇을-읽고-어디로-보내는가) 를 보세요.

**색상이나 임계치를 바꿀 수 있나요?**
설정으로는 안 됩니다. 스크립트가 짧고 읽기 쉬우니 fork 해서 셸 구현의 `c_of`, PowerShell 구현의 `Get-Colours` 를 고치세요.

**`CLAUDE_CONFIG_DIR` 를 커스텀으로 쓰면요?**
설정 디렉터리는 존중합니다. 다만 macOS 키체인 조회는 아닙니다 — `CLAUDE_CONFIG_DIR` 가 설정되면 Claude Code 가 키체인 서비스명에 해시를 덧붙이는데 그 조합은 지원하지 않습니다. 5h/7d 값이 나오지 않습니다.

**Windows 에서 셸 구현을 쓸 수 있나요?**
Git Bash 와 `jq` 가 있으면 됩니다. clone 에서 `scripts/install.sh` 를 실행하세요. 다만 `PATH` 의 `bash` 는 Git Bash 가 아니라 WSL 스텁일 가능성이 높습니다.

## 개발

```bash
sh tests/run-tests.sh                                                    # macOS, Linux, Git Bash
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1   # Windows
```

두 러너가 [`tests/cases/`](tests/cases) 의 같은 케이스를 읽으므로 두 구현이 한 가지 기준으로 검증됩니다. 케이스를 추가하기 전에 [tests/README.md](tests/README.md) 를 보세요.

## 라이선스

[MIT](LICENSE)
