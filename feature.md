# Feature Plan: Vendor Base URL from TOML Config

## Goal
Add optional TOML sections for all vendors (`openai`, `gemini`, `ollama`) so users can define a default `base_url` per vendor.

Base URL resolution must follow this precedence:
1. CLI `--base-url` / `-b` (always wins)
2. Vendor `base_url` from config file (if defined)
3. Existing hardcoded fallback (if config value is missing)

## Current State
- `Config.t` only contains `ollama.url`.
- Vendor base URL behavior is not consistently configurable for all vendors.
- Runtime defaults are currently hardcoded in code paths.

## Target TOML Schema
All vendor sections remain optional.

```toml
[openai]
base_url = "https://api.openai.com/v1"

[gemini]
base_url = "https://generativelanguage.googleapis.com"

[ollama]
base_url = "http://localhost:11434"
```

Notes:
- Missing section is valid.
- Present section without `base_url` is valid.
- Existing behavior should be preserved when config is absent.

## Implementation Plan

### 1. Extend Config Types
Files:
- `lib/config.mli`
- `lib/config.ml`

Changes:
- Add optional vendor config records for:
  - `openai` with `base_url: string option`
  - `gemini` with `base_url: string option`
  - `ollama` with `base_url: string option`
- Update `Config.t` to include all three vendor sections.
- Keep defaults so missing keys/sections never crash parsing.

### 2. Parse New TOML Keys
File:
- `lib/config.ml`

Changes:
- Add TOML lenses for:
  - `openai.base_url`
  - `gemini.base_url`
  - `ollama.base_url`
- In `of_toml`, populate optional values using `Toml.Lenses.get`.
- Preserve vendor-specific hardcoded base URL defaults in runtime resolution.

### 3. Add CLI Support for Global Base URL Override
Files:
- `bin/main.ml`
- any CLI parsing module used by `Params` (if separate)

Changes:
- Add `--base-url` / `-b` parameter to CLI params.
- Ensure value is propagated into runtime selection logic.

### 4. Wire Config Into Runtime Base URL Selection
File:
- `bin/main.ml`

Changes:
- In each vendor branch, compute `base_url` with:
  - `params.base_url`
  - else vendor base URL from config
  - else current hardcoded default
- Use resolved URL when constructing each vendor client.

Suggested helper in `main.ml`:
- `resolve_base_url ~cli_base_url ~config_base_url ~hardcoded_default`
  to keep precedence logic identical across vendors.

### 5. Update and Add Tests
Files:
- add `test/test_config.ml`
- update `test/dune`
- update `test/test_suite.ml`

Test cases:
- `Config.load` with no file: optional base URLs are `None`.
- Parse each vendor base URL from TOML.
- Parse partial config (only one vendor section) without affecting others.
- Precedence helper behavior:
  - CLI base URL set -> always selected.
  - CLI unset + config base URL set -> config selected.
  - both unset -> hardcoded selected.

### 6. Documentation Update
Files:
- `README.md`

Changes:
- Add config section with new TOML example.
- Document precedence rule explicitly:
  - `--base-url/-b` > config `base_url` > hardcoded default.

## Acceptance Criteria
- User can define `[openai].base_url`, `[gemini].base_url`, `[ollama].base_url`.
- All vendor sections are optional; missing sections do not fail load.
- Existing behavior is preserved when no base URL is set in config.
- CLI `--base-url/-b` always overrides config and hardcoded defaults.
- Tests cover parsing and precedence behavior.

## Out of Scope
- Changing model selection precedence.
- Changing vendor names or command structure beyond adding `--base-url/-b`.
