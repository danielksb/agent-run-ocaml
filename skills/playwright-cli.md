---
name: playwright-cli
description: use this skill when you need to automate browser interactions to access websites.
---

## Purpose

Use Playwright CLI for token-efficient browser automation from coding agents.
Prefer snapshot refs (`e15`) for stable interactions.

## Invocation

- Global: `playwright-cli <command> [args] [options]`
- Local: `npx playwright-cli <command> [args] [options]`
- Named session: `playwright-cli -s=<session> <command> ...`

## Session Management (Required)

- Always use a named session for multi-step flows: `-s=<name>`.
- Reuse the same session name for every command in one task.
- Start with `open` in that session, then continue all actions in the same session.
- Do not call `close` unless the user explicitly asks to close the browser.
- In `agent-run` with `exec_command`, avoid `--persistent` by default because it can keep `open` alive and block the next tool call.
- Use `--headed` on `open` so the browser window is visible while the task runs.
- `open` can be long-running in headed mode. In `agent-run`, launch it in background so the next tool call can run.

Background `open` commands:
- Windows (PowerShell): `Start-Process -FilePath npx -ArgumentList 'playwright-cli','-s=todo','open','https://demo.playwright.dev/todomvc/','--headed'`
- Linux/macOS (sh): `nohup npx playwright-cli -s=todo open https://demo.playwright.dev/todomvc/ --headed >/tmp/playwright-cli-open.log 2>&1 &`

Recommended pattern:
- Windows: `Start-Process -FilePath npx -ArgumentList 'playwright-cli','-s=todo','open','https://demo.playwright.dev/todomvc/','--headed'`
- Linux/macOS: `nohup npx playwright-cli -s=todo open https://demo.playwright.dev/todomvc/ --headed >/tmp/playwright-cli-open.log 2>&1 &`
- `npx playwright-cli -s=todo type "Learn Ocaml"`
- `npx playwright-cli -s=todo press Enter`
- `npx playwright-cli -s=todo snapshot --filename=todo.yaml`

## Example (Updated)

1. Windows: `Start-Process -FilePath npx -ArgumentList 'playwright-cli','-s=todo','open','https://demo.playwright.dev/todomvc/','--headed'`
2. Linux/macOS: `nohup npx playwright-cli -s=todo open https://demo.playwright.dev/todomvc/ --headed >/tmp/playwright-cli-open.log 2>&1 &`
3. `npx playwright-cli -s=todo type "Buy groceries"`
4. `npx playwright-cli -s=todo press Enter`
5. `npx playwright-cli -s=todo type "Water flowers"`
6. `npx playwright-cli -s=todo press Enter`
7. `npx playwright-cli -s=todo check e21`
8. `npx playwright-cli -s=todo check e35`
9. `npx playwright-cli -s=todo screenshot --filename=todos.png`

## Commands

### Core
- `npx playwright-cli open [url]`
- `npx playwright-cli goto <url>`
- `npx playwright-cli close`
- `npx playwright-cli type <text>`
- `npx playwright-cli click <ref> [button]`
- `npx playwright-cli dblclick <ref> [button]`
- `npx playwright-cli fill <ref> <text>`
- `npx playwright-cli fill <ref> <text> --submit`
- `npx playwright-cli drag <startRef> <endRef>`
- `npx playwright-cli hover <ref>`
- `npx playwright-cli select <ref> <val>`
- `npx playwright-cli upload <file>`
- `npx playwright-cli check <ref>`
- `npx playwright-cli uncheck <ref>`
- `npx playwright-cli snapshot`
- `npx playwright-cli snapshot --filename=<file>`
- `npx playwright-cli snapshot <ref>`
- `npx playwright-cli snapshot --depth=<N>`
- `npx playwright-cli eval <func> [ref]`
- `npx playwright-cli dialog-accept [prompt]`
- `npx playwright-cli dialog-dismiss`
- `npx playwright-cli resize <w> <h>`
- `npx playwright-cli delete-data`

### Navigation
- `npx playwright-cli go-back`
- `npx playwright-cli go-forward`
- `npx playwright-cli reload`

### Keyboard
- `npx playwright-cli press <key>`
- `npx playwright-cli keydown <key>`
- `npx playwright-cli keyup <key>`

### Mouse
- `npx playwright-cli mousemove <x> <y>`
- `npx playwright-cli mousedown [button]`
- `npx playwright-cli mouseup [button]`
- `npx playwright-cli mousewheel <dx> <dy>`

### Save As
- `npx playwright-cli screenshot [ref]`
- `npx playwright-cli screenshot --filename=<file>`
- `npx playwright-cli pdf`
- `npx playwright-cli pdf --filename=<file>`

### Tabs
- `npx playwright-cli tab-list`
- `npx playwright-cli tab-new [url]`
- `npx playwright-cli tab-close [index]`
- `npx playwright-cli tab-select <index>`

### Storage
- `npx playwright-cli state-save [filename]`
- `npx playwright-cli state-load <filename>`
- `npx playwright-cli cookie-list [--domain]`
- `npx playwright-cli cookie-get <name>`
- `npx playwright-cli cookie-set <name> <val>`
- `npx playwright-cli cookie-delete <name>`
- `npx playwright-cli cookie-clear`
- `npx playwright-cli localstorage-list`
- `npx playwright-cli localstorage-get <key>`
- `npx playwright-cli localstorage-set <k> <v>`
- `npx playwright-cli localstorage-delete <k>`
- `npx playwright-cli localstorage-clear`
- `npx playwright-cli sessionstorage-list`
- `npx playwright-cli sessionstorage-get <k>`
- `npx playwright-cli sessionstorage-set <k> <v>`
- `npx playwright-cli sessionstorage-delete <k>`
- `npx playwright-cli sessionstorage-clear`

### Network
- `npx playwright-cli route <pattern> [opts]`
- `npx playwright-cli route-list`
- `npx playwright-cli unroute [pattern]`

### DevTools
- `npx playwright-cli console [min-level]`
- `npx playwright-cli network`
- `npx playwright-cli run-code <code>`
- `npx playwright-cli run-code --filename=<file>`
- `npx playwright-cli tracing-start`
- `npx playwright-cli tracing-stop`
- `npx playwright-cli video-start [filename]`
- `npx playwright-cli video-chapter <title>`
- `npx playwright-cli video-stop`
- `npx playwright-cli show`

### Session Management
- `npx playwright-cli list`
- `npx playwright-cli close-all`
- `npx playwright-cli kill-all`
- `npx playwright-cli -s=<name> close`
- `npx playwright-cli -s=<name> delete-data`

### Open Options
- `npx playwright-cli open --browser=chrome`
- `npx playwright-cli open --headed`
- `npx playwright-cli open --extension`
- `npx playwright-cli open --persistent`
- `npx playwright-cli open --profile=<path>`
- `npx playwright-cli open --config=<file.json>`

## Snapshot and Targeting Guidance

- After each command, CLI can provide a snapshot; use `snapshot` explicitly when needed.
- Prefer refs from snapshot (`e15`) for interactions.
- You can also target CSS selectors or Playwright locator expressions.
- Re-snapshot after navigation or major DOM changes before using refs again.
- Run one CLI command per tool call and wait for it to finish before issuing the next command.
