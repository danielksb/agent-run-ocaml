---
name: playwright-cli
description: use this skill when you need to automate browser interactions to access websites.
---

## Purpose

This skill guides an LLM to:
- open and navigate websites,
- find and interact with elements,
- fill forms reliably,
- capture DOM snapshots and screenshots for verification.

## Tool Assumption

Commands are executed with `npx playwright-cli ...`.

Optional session form:
- `npx playwright-cli -s=<session> <command> ...`

## Core Workflow

1. Start browser and open target page.
2. Capture a snapshot to discover element refs.
3. Interact with page elements (click/fill/select/check/upload).
4. Re-snapshot after meaningful state changes.
5. Capture screenshot for evidence.
6. Save auth/storage state if the flow needs reuse.

## Command Patterns

### Navigation
- `npx playwright-cli open <url>`
- `npx playwright-cli goto <url>`
- `npx playwright-cli reload`
- `npx playwright-cli go-back`
- `npx playwright-cli go-forward`

### Element Discovery
- `npx playwright-cli snapshot`
- `npx playwright-cli snapshot <element>`

Use snapshots frequently. Prefer acting on fresh element references after navigation or rerender.

### Form and Interaction
- `npx playwright-cli click <target>`
- `npx playwright-cli fill <target> "<text>"`
- `npx playwright-cli type "<text>"`
- `npx playwright-cli select <target> <value>`
- `npx playwright-cli check <target>`
- `npx playwright-cli uncheck <target>`
- `npx playwright-cli upload <file>`
- `npx playwright-cli press <key>`

Prefer `fill` over `type` for deterministic field input.

### Evidence and Output
- `npx playwright-cli snapshot`
- `npx playwright-cli screenshot`
- `npx playwright-cli screenshot <target>`
- `npx playwright-cli pdf`

Use `snapshot` for machine-readable state and `screenshot` for visual confirmation.

## Reliability Rules

- Always snapshot before first interaction on a page.
- Re-snapshot after clicks that may trigger DOM updates.
- If an action fails, refresh snapshot and retry with updated target.
- Keep actions small and verifiable (act, then inspect).
- Use explicit navigation (`goto`) instead of assuming redirects finished.

## Example Flow

1. `npx playwright-cli open https://example.com/login`
2. `npx playwright-cli snapshot`
3. `npx playwright-cli fill <email_input_ref> "user@example.com"`
4. `npx playwright-cli fill <password_input_ref> "secret"`
5. `npx playwright-cli click <submit_button_ref>`
6. `npx playwright-cli snapshot`
7. `npx playwright-cli screenshot`

## Session Reuse (Optional)

- Save state: `npx playwright-cli state-save auth-state.json`
- Load state: `npx playwright-cli state-load auth-state.json`

Useful for skipping repeated logins in multi-step workflows.

