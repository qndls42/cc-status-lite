---
name: statusline-install
description: statusline-pro 상태줄을 설치한다. 사용자가 "상태줄 설치", "statusline 설치", "/statusline-install" 이라고 하거나 statusline-pro 를 켜고 싶다고 할 때 사용한다.
---

# statusline-pro 설치

`${CLAUDE_PLUGIN_ROOT}/scripts/install.sh` 를 실행하고 출력을 사용자에게 그대로 보고한다.

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"
```

## 규칙

- 스크립트가 모든 작업을 한다. JSON 을 직접 편집하지 말 것.
- `jq` 가 없어서 실패하면 출력에 안내된 설치 명령을 사용자에게 그대로 전달한다. 대신 설치해 주지 말 것.
- 스크립트가 "기존 statusLine 을 백업했습니다" 를 출력하면 **반드시** 사용자에게 알린다. 다른 상태줄을 덮어쓴 것이며 `/statusline-uninstall` 로 되돌릴 수 있다.
- 마지막에 다음을 전달한다: 새 세션부터 반영되고, 5h/7d 는 첫 갱신까지 최대 1분 걸린다.

## 설치되는 것

두 줄 상태줄:

```
[Opus 5] ~/my-project (main)
🧠 32% (64k/200k)  ⏳ 5h 21%  📅 7d 30%
```

- 🧠 컨텍스트 사용률 / 사용 토큰 / 최대
- ⏳ 5시간 한도, 📅 주간 한도 — 색상은 70% 노랑, 90% 빨강
- 갱신 실패가 15분 넘으면 값을 숨기지 않고 흐리게 표시

사용자가 5h/7d 가 안 보인다고 하면 `${CLAUDE_PLUGIN_ROOT}/README.md` 의 문제 해결 항목을 확인한다.
