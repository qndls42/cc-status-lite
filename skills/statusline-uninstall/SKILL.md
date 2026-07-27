---
name: statusline-uninstall
description: statusline-pro 상태줄을 제거하고 이전 statusLine 을 복원한다. 사용자가 "상태줄 제거", "statusline 삭제", "/statusline-uninstall" 이라고 할 때 사용한다.
---

# statusline-pro 제거

`${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh` 를 실행하고 출력을 사용자에게 그대로 보고한다.

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh"
```

## 규칙

- 현재 statusLine 이 statusline-pro 가 아니면 스크립트는 아무것도 건드리지 않고 종료한다. 그 결과를 그대로 전달할 것.
- 설치 시 백업해 둔 이전 statusLine 이 있으면 자동 복원된다. 없으면 `statusLine` 키를 지운다.
- `settings.json.bak.statusline-pro` 백업 파일은 남겨둔다. 사용자가 명시적으로 요청하지 않는 한 지우지 말 것.
