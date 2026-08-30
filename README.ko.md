<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/example-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/example-light.svg">
    <img alt="cc-status-lite를 적용한 Claude Code 화면. 첫 줄에 모델과 경로, 둘째 줄에 컨텍스트 사용량과 5시간·주간 한도가 초기화 시각과 함께 표시됩니다." src="assets/example-light.svg" width="760">
  </picture>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <a href="https://github.com/qndls42/cc-status-lite/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/qndls42/cc-status-lite"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%20%C2%B7%20Linux%20%C2%B7%20Windows-lightgrey">
  <a href="README.md"><img alt="English" src="https://img.shields.io/badge/README-English-lightgrey"></a>
</p>

# 남은 사용량, 터미널에서 바로

터미널 맨 아래 두 줄입니다. 왼쪽은 컨텍스트를 얼마나 썼는지, 오른쪽은 5시간·주간 한도가 얼마나 남았는지. 각각 몇 시에 초기화되는지까지 같이 나옵니다.

Claude Code가 상태줄에 넘겨주는 정보에는 컨텍스트 사용량은 있어도 한도는 없습니다. 정작 "이거 하나 더 돌려도 되나" 싶을 때 보고 싶은 건 한도 쪽인데 말이죠. cc-status-lite는 Claude Code가 쓰는 것과 같은 API에서 그 값을 직접 가져옵니다. 1분간 캐시해두고 갱신은 백그라운드에서 하니, 이것 때문에 터미널이 멈칫하는 일은 없습니다.

macOS·Linux용 셸 스크립트와 Windows용 PowerShell 스크립트, 두 벌이 같은 테스트를 통과합니다.

## 설치

명령 세 줄이면 끝납니다. 앞의 둘은 Claude Code 안에서 칩니다.

### 1. 마켓플레이스 등록

```
/plugin marketplace add qndls42/cc-status-lite
```

### 2. 플러그인 설치

```
/plugin install cc-status-lite@cc-status-lite
```

### 3. 상태줄 켜기

Claude Code를 재시작하면 다음 세션에서 Claude가 상태줄을 켤지 물어봅니다. 켜달라고 하면 끝입니다.

직접 켜려면 이렇게 하세요.

```
/statuslite-install
```

> [!TIP]
> 두 줄이 뜨고, 퍼센트에 색이 들어가고, 1분 안에 5h/7d 숫자가 채워지면 제대로 된 겁니다. 첫 줄만 나오고 둘째 줄이 비어 있다면 플러그인만 깔리고 상태줄은 안 켜진 상태니 `/statuslite-install`을 실행하세요.

### 준비물

| 플랫폼 | 필요한 것 |
|---|---|
| **macOS · Linux** | `jq` |
| **Windows** | 없음 |

따로 깔아야 할 수도 있는 건 `jq` 하나뿐이고, 설치 스크립트도 이것만 확인합니다. 상태줄이 `curl`과 `git`도 부르긴 하지만 둘 다 macOS와 주요 리눅스에 기본으로 들어 있습니다. 혹시 없는 환경이라면 한도 값(`curl`)이나 브랜치(`git`)만 빠지고 나머지는 그대로 나옵니다.

<details>
<summary><strong>macOS · Linux</strong> — <code>jq</code> 설치하기</summary>

<br>

`jq`가 없으면 설치 스크립트가 플랫폼에 맞는 명령을 알려주고 멈춥니다. 알아서 깔아주지는 않습니다.

```bash
brew install jq          # macOS
sudo apt install jq      # Debian, Ubuntu
sudo dnf install jq      # Fedora
```

</details>

<details>
<summary><strong>Windows</strong> — 준비물이 없는 이유</summary>

<br>

Windows에서는 PowerShell 구현이 돌아갑니다. PowerShell도 `curl.exe`도 Windows 10 1803부터 기본으로 들어 있고, JSON 파싱(`ConvertFrom-Json`)도 내장이라 Git Bash나 `jq`를 따로 깔 필요가 없습니다.

Git Bash와 `jq`가 이미 있다면 저장소를 받아서 `scripts/install.sh`를 돌려도 됩니다. 출력은 똑같습니다. PowerShell 쪽을 기본으로 삼은 건 아무것도 안 깔아도 되기 때문입니다.

한 가지 함정이 있습니다. Windows에서 `PATH`에 잡히는 `bash`는 Git Bash가 아니라 WSL 실행기인 경우가 많습니다. 셸 구현을 쓰려면 `C:\Program Files\Git\bin\bash.exe`처럼 전체 경로로 불러야 합니다.

</details>

## 상태줄 읽기

```
[Opus 5] ~/my-project (main)
🧠 32% (64k/200k)  🕐 5h 21% (08/31 14:49)  📅 7d 46% (09/03 17:59)
```

| 구간 | 뜻 |
|---|---|
| `[Opus 5]` | 지금 세션이 쓰는 모델 |
| `~/my-project (main)` | 작업 폴더(홈은 `~`로 줄임)와, 저장소라면 git 브랜치 |
| 🧠 `32% (64k/200k)` | 컨텍스트 사용률, 쓴 토큰, 컨텍스트 창 크기 |
| 🕐 `5h 21% (08/31 14:49)` | 5시간 한도와 초기화되는 시각 |
| 📅 `7d 46% (09/03 17:59)` | 주간 한도와 초기화되는 시각 |

숫자를 안 읽어도 색만 보면 대충 감이 옵니다.

| | 퍼센트 | 초기화 시각 |
|---|---|---|
| **70% 미만** | 초록 | 흐리게 |
| **70% 이상** | 노랑 | 노랑 |
| **90% 이상** | 빨강 | 빨강 |
| **오래된 값** | 흐리게 | 흐리게 |

전부 흐리게 나온다면 15분 넘게 갱신에 실패했다는 뜻입니다. 대개 토큰이 만료된 경우인데 Claude Code가 알아서 다시 받아옵니다. 값을 지워버리지 않고 흐리게만 처리해서, 최신은 아니어도 참고는 할 수 있게 남겨둡니다.

## 이렇게 만든 이유

### #1 한도는 애초에 넘어오지 않는다

**문제.** Claude Code가 상태줄에 주는 건 모델, 작업 폴더, 컨텍스트 창까지입니다. 5시간·주간 사용률은 없습니다. 작업을 더 돌릴지 말지 판단할 때 정작 필요한 숫자가 빠져 있는 셈입니다.

**해결.** `https://api.anthropic.com/api/oauth/usage`로 인증 요청을 한 번 보냅니다. Claude Code가 쓰는 것과 같은 주소입니다. 결과는 1분간 캐시하고, 갱신은 따로 떨어진 백그라운드 프로세스가 맡습니다. 그래서 화면을 그릴 때 네트워크를 기다리는 일이 없습니다. 갱신에 실패해도 마지막 값을 버리지 않고 흐리게 보여줍니다.

### #2 플러그인은 상태줄을 건드릴 수 없다

**문제.** [플러그인 문서](https://code.claude.com/docs/en/plugins-reference)를 보면 플러그인 설정에서 쓸 수 있는 건 `agent`와 `subagentStatusLine`뿐입니다. 정작 메인 `statusLine`은 안 됩니다. 게다가 `settings.json` 안에서는 `${CLAUDE_PLUGIN_ROOT}`가 풀리지 않는데, 플러그인 폴더 경로에는 버전이 들어 있어서 업데이트할 때마다 주소가 바뀝니다.

**해결.** `settings.json`에는 딱 한 번, 설정 폴더 안의 고정된 경로를 적어둡니다. 그다음부터는 `SessionStart` 훅이 세션마다 그 파일과 플러그인 원본을 비교해서 다르면 새로 복사합니다. 덕분에 `/plugin update` 한 번이면 되고, `git pull`이나 재설치는 필요 없습니다.

### #3 Windows를 덤으로 두지 않았다

**문제.** Windows에서 셸 스크립트를 쓰겠다는 건 Git Bash와 `jq`를 깔라는 얘기입니다. 30초면 설치하는 도구치고는 요구가 과합니다.

**해결.** 겉만 감싼 게 아니라 PowerShell로 따로 구현했습니다. 두 구현이 [`tests/cases/`](tests/cases)의 같은 케이스를 각자의 러너로 검증받으니 슬금슬금 달라질 수가 없습니다. 실제로 이 과정에서 macOS만 봐서는 나올 수 없는 버그들이 나왔습니다. `[char]`로 이모지가 소리 없이 사라지고, .NET 날짜 형식의 `/`가 로케일 구분자로 바뀌어 `08-30`으로 찍히고, 파일을 UTF-8이 아니라 시스템 코드페이지로 읽어버리는 문제들이었습니다.

## 무엇을 읽고 어디로 보내나

이 플러그인은 Claude 자격증명을 읽습니다. 감출 일이 아니니 먼저 밝힙니다.

**읽는 것.** Claude Code가 쓰는 OAuth 액세스 토큰입니다. macOS에서는 키체인(`security find-generic-password -s 'Claude Code-credentials'`), 나머지 플랫폼에서는 `~/.claude/.credentials.json`에서 가져옵니다.

**보내는 곳.** `https://api.anthropic.com/api/oauth/usage` 한 곳뿐입니다. 주소는 코드에 박아뒀고 환경 변수 같은 게 끼어들 여지가 없습니다. 다른 통신도, 사용 기록 수집도, 제3자 서비스도 없습니다.

**토큰 다루는 방식.** 명령줄 인자로는 절대 넘기지 않습니다. 프로세스 인자는 macOS의 `ps`나 Linux의 `/proc/<pid>/cmdline`으로 누구나 들여다볼 수 있어서, 인자로 넘기면 같은 컴퓨터를 쓰는 다른 사용자가 토큰을 가져갈 수 있습니다. 키체인을 못 여는 권한 없는 프로그램도 마찬가지고요. 그래서 셸 쪽은 `curl --config -`로 표준입력에 흘려보내고, PowerShell 쪽은 메모리에만 둡니다. 토큰을 디스크에 쓰지 않고, 갱신하거나 저장하지도 않습니다.

**쓰는 것.** `~/.claude/.cc-status-lite-cache.json` 하나입니다. 권한은 `600`이고, 5시간·주간의 `utilization`과 `resets_at` 네 개만 들어갑니다. API 응답에는 지출액이나 크레딧 잔액도 딸려오지만 화면에 안 쓰는 값이라 저장하지 않고 버립니다.

**설정에서 바꾸는 것.** `statusLine` 키 하나뿐입니다. 그 전에 `settings.json`을 백업해두고, 원래 쓰던 상태줄이 있었다면 따로 기록해서 나중에 되돌릴 수 있게 합니다.

**하지 않는 것.** 토큰 갱신, 자격증명 기록, `api.anthropic.com` 외 통신, 데이터 외부 전송. 하나도 하지 않습니다.

여기 적은 내용은 전부 [`scripts/statusline.sh`](scripts/statusline.sh)나 [`scripts/statusline.ps1`](scripts/statusline.ps1) 몇 줄에 들어 있습니다. 설치 전에 통째로 읽어볼 만한 분량이니 한번 훑어보시길 권합니다.

## 업데이트

```
/plugin update cc-status-lite@cc-status-lite
```

이게 전부입니다. 다음 세션에서 `SessionStart` 훅이 설치된 파일을 알아서 맞춰줍니다.

## 제거

```
/statuslite-uninstall
```

원래 쓰던 상태줄이 있었으면 되돌리고, 없었으면 키만 지웁니다. `settings.json`의 나머지는 그대로 둡니다. 플러그인까지 지우려면 이렇게 하세요.

```
/plugin uninstall cc-status-lite@cc-status-lite
```

## 저장소 구성

| 경로 | 내용 |
|---|---|
| [`scripts/statusline.sh`](scripts/statusline.sh) · [`.ps1`](scripts/statusline.ps1) | 상태줄 본체. 플랫폼마다 한 벌씩 |
| [`scripts/install.sh`](scripts/install.sh) · [`.ps1`](scripts/install.ps1) | `statusLine` 키를 쓰고 기존 값을 백업 |
| [`scripts/uninstall.sh`](scripts/uninstall.sh) · [`.ps1`](scripts/uninstall.ps1) | 되돌리고 파일 정리 |
| [`scripts/json-format.ps1`](scripts/json-format.ps1) | PowerShell이 `settings.json` 전체를 헤집지 않도록 |
| [`hooks/`](hooks) | 설치된 파일을 최신으로 유지하는 `SessionStart` 훅 |
| [`skills/`](skills) | `/statuslite-install`, `/statuslite-uninstall` |
| [`tests/`](tests) | 공유 케이스와 구현별 러너 |

### 동작 요약

| 항목 | 내용 |
|---|---|
| 갱신 주기 | 최대 1분에 한 번, 별도 프로세스에서 |
| 대기 여부 | 없음. 화면 그릴 땐 캐시만 읽음 |
| 오래된 값 기준 | 갱신 성공 없이 15분 |
| 색 기준 | 70%부터 노랑, 90%부터 빨강 |
| 초기화 시각 | API가 주는 UTC를 현지 시각으로 변환 |
| 캐시 | 네 개 필드, 권한 `600` |
| 설정 변경 | 백업 후 `statusLine` 키 하나 |
| 업데이트 | 훅이 알아서 맞춤. 재설치 불필요 |

## 문제 해결

**5h/7d 값이 안 보입니다.**
첫 갱신까지 최대 1분 걸립니다. 그 뒤에도 안 나오면 `~/.claude/.cc-status-lite-cache.json`이 있는지 확인해보세요. 없으면 토큰을 못 찾은 겁니다. Claude Code에서 다시 로그인하고 새 세션을 시작하면 됩니다.

**값은 나오는데 계속 흐립니다.**
15분 넘게 갱신에 실패했다는 뜻이고 대개 토큰 만료입니다. Claude Code가 자격증명을 다시 받아오면 다음 호출부터 정상으로 돌아옵니다.

**아무것도 안 보입니다.**
`~/.claude/settings.json`의 `statusLine`이 `cc-status-lite`를 가리키는지 확인하고, 스크립트를 직접 돌려보세요.

```bash
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$HOME"'"},"context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000}}' \
  | bash ~/.claude/cc-status-lite.sh
```

**Windows에서 `bad interpreter: /bin/sh^M`가 뜹니다.**
스크립트가 CRLF로 받아진 경우입니다. `.gitattributes`가 LF로 고정해두긴 했으니, 다시 clone 받거나 `git config core.autocrlf false` 후 체크아웃하면 됩니다.

**`/statuslite-install`이 두 번 나옵니다.**
예전에 수동으로 받아둔 clone이 `~/.claude/skills/`에 남아 있습니다. 플러그인이 대신하니 지우면 됩니다.

## 자주 묻는 질문

**터미널이 느려지지 않나요?**
안 느려집니다. 화면을 그릴 때는 캐시 파일만 읽습니다. 네트워크 요청은 따로 떨어진 프로세스가 최대 1분에 한 번 보내고, 상태줄은 그 결과를 기다리지 않습니다.

**왜 자격증명까지 필요한가요?**
한도 사용률이 Claude Code가 상태줄에 넘겨주는 정보에 없기 때문입니다. 직접 조회해야 하고, 그러려면 본인 계정으로 인증해야 합니다. 자세한 건 [무엇을 읽고 어디로 보내나](#무엇을-읽고-어디로-보내나)에 적어뒀습니다.

**색이나 기준값을 바꿀 수 있나요?**
설정으로는 안 됩니다. 대신 스크립트가 짧으니 포크해서 셸 쪽은 `c_of`, PowerShell 쪽은 `Get-Colours` 함수를 고치면 됩니다.

**`CLAUDE_CONFIG_DIR`를 따로 지정해서 씁니다.**
설정 폴더 위치는 그대로 따라갑니다. 다만 macOS 키체인 조회는 안 됩니다. `CLAUDE_CONFIG_DIR`가 설정되면 Claude Code가 키체인 이름 뒤에 해시를 붙이는데 거기까지는 지원하지 않습니다. 이 경우 5h/7d 값이 안 나옵니다.

**Windows에서 셸 구현을 쓰고 싶습니다.**
Git Bash와 `jq`가 있으면 됩니다. 저장소를 받아서 `scripts/install.sh`를 실행하세요. 다만 `PATH`의 `bash`는 Git Bash가 아니라 WSL일 가능성이 높으니 전체 경로로 부르셔야 합니다.

## 개발

```bash
sh tests/run-tests.sh                                                    # macOS, Linux, Git Bash
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1   # Windows
```

두 러너가 [`tests/cases/`](tests/cases)의 같은 케이스를 읽으니 구현이 달라도 기준은 하나입니다. 케이스를 추가하기 전에 [tests/README.md](tests/README.md)를 먼저 보세요.

## 라이선스

[MIT](LICENSE)
