# Feature Plan: Vendor Default Models from TOML Config

## Goal
Add optional TOML sections for all vendors (`openai`, `gemini`, `ollama`) so users can define a default model per vendor.

Model resolution must follow this precedence:
1. CLI `--model` / `-m` (always wins)
2. Vendor model from config file (if defined)
3. Existing hardcoded fallback (if config model is missing)

## Current State
- `Config.t` only contains `ollama.url`.
- Hardcoded model defaults live in `bin/main.ml`:
  - OpenAI: `gpt-4o-mini`
  - Gemini: `gemini-flash-latest`
  - Ollama: `functiongemma`
- `--model/-m` already overrides hardcoded defaults.

## Target TOML Schema
All vendor sections remain optional.

```toml
[openai]
model = "gpt-4.1-mini"

[gemini]
model = "gemini-2.5-flash"

[ollama]
url = "http://localhost:11434"
model = "functiongemma"
```

Notes:
- Missing section is valid.
- Present section without `model` is valid.
- Existing `ollama.url` behavior remains unchanged.

## Implementation Plan

### 1. Extend Config Types
Files:
- `lib/config.mli`
- `lib/config.ml`

Changes:
- Add optional vendor config records:
  - `openai` with `model: string option`
  - `gemini` with `model: string option`
  - `ollama` extended to include `model: string option` (keep `url: string`)
- Update `Config.t` to include all three vendor sections.
- Keep defaults so missing keys/sections never crash parsing.

### 2. Parse New TOML Keys
File:
- `lib/config.ml`

Changes:
- Add TOML lenses for:
  - `openai.model`
  - `gemini.model`
  - `ollama.model`
  - retain `ollama.url`
- In `of_toml`, populate optional models using `Toml.Lenses.get`.
- Preserve old fallback for `ollama.url` (`http://localhost:11434`).

### 3. Wire Config Into Runtime Model Selection
File:
- `bin/main.ml`

Changes:
- In each vendor branch, compute `model_name` with:
  - `params.model_name`
  - else vendor model from config
  - else current hardcoded default
- Use `app_config.ollama.url` when creating Ollama agent (this also fixes currently ignored config value).

Suggested helper in `main.ml`:
- `resolve_model ~cli_model ~config_model ~hardcoded_default`
  to keep precedence logic identical across vendors.

### 4. Update and Add Tests
Files:
- add `test/test_config.ml`
- update `test/dune`
- update `test/test_suite.ml`

Test cases:
- `Config.load` with no file: optional models are `None`, `ollama.url` default unchanged.
- Parse each vendor model from TOML.
- Parse partial config (only one vendor section) without affecting others.
- Keep passing when sections are absent.

If integration-style tests for `bin/main.ml` are not present yet:
- add a small pure helper test for precedence logic (preferred), e.g.:
  - CLI model set -> always selected.
  - CLI unset + config model set -> config selected.
  - both unset -> hardcoded selected.

### 5. Documentation Update
Files:
- `README.md`

Changes:
- Add config section with new TOML example.
- Document precedence rule explicitly:
  - `--model/-m` > config model > hardcoded default.

## Acceptance Criteria
- User can define `[openai].model`, `[gemini].model`, `[ollama].model`.
- All vendor sections are optional; missing sections do not fail load.
- Existing behavior is preserved when no model is set in config.
- CLI `--model/-m` always overrides config and hardcoded defaults.
- `ollama.url` continues to work from config.
- Tests cover parsing and precedence behavior.

## Out of Scope
- Adding config-driven `base_url` for OpenAI/Gemini.
- Changing CLI argument format or vendor names.
