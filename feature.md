# Feature: Skill Support via `--skill` / `-s`

## Goal
Allow users to pass a `SKILL.md` file to `agent-run` with `--skill <path>` (or `-s <path>`).

V1 behavior:
- Parse YAML frontmatter from the skill file.
- Inject a short skill-usage instruction plus extracted frontmatter into request context.
- Tell the model to read the full `SKILL.md` content via tools when it needs detailed instructions.

Reference spec: https://agentskills.io/specification

## Scope (V1)
- Support exactly one skill file path from CLI.
- Parse only frontmatter block (`--- ... ---`) + extract known fields.
- No skill directory scanning/discovery.
- No automatic loading of skill body into context.
- No enforcement for `allowed-tools` yet.

## UX
Command example:
```bash
agent-run --vendor openai --skill ./my-skill/SKILL.md --prompt "..."
```

If `--skill` is provided:
- Frontmatter is parsed.
- Prompt is augmented with a short "how to use skills" section and the parsed frontmatter.
- The prompt includes explicit instruction to call `read_file` on the provided `SKILL.md` path when deeper guidance is required.

## Design

### 1. CLI + params wiring
- Add `skill_path: string option` to CLI params in `bin/main.ml`.
- Parse `--skill` / `-s` in `parse_params`.
- Update `usage()` text.

### 2. Skill parser module
Add new module: `lib/skill.ml` (and `lib/skill.mli`)

Responsibilities:
- Read file content.
- Extract frontmatter block between first two `---` delimiters.
- Parse key/value fields from frontmatter into typed record.

Minimal typed model:
- `name: string option`
- `description: string option`
- `license: string option`
- `compatibility: string option`
- `metadata: (string * string) list`
- `allowed_tools: string option`
- `skill_path: string`

Validation (V1):
- Require valid frontmatter delimiters if file provided.
- Require non-empty `name` and `description` (spec-required fields).
- Return descriptive error messages for invalid/missing frontmatter.

Implementation note:
- Start with a small line-based parser for simple YAML subset used in V1.
- Parse top-level scalar fields plus one-level `metadata:` map.
- Do not support full YAML complexity in V1; fail clearly on unsupported shape.

### 3. Prompt augmentation
Add helper in `bin/main.ml` (or small module in `lib/`):
- `build_prompt_with_skill : prompt:string -> skill:Skill.frontmatter -> string`

Injected context format:
1. Short policy text:
   - A skill is available.
   - Use frontmatter to decide whether skill applies.
   - If skill is needed, read full `SKILL.md` using `read_file` with exact path.
2. Include parsed frontmatter as structured text/json snippet.
3. Include absolute skill file path.
4. Append original user prompt unchanged at the end.

Important:
- Keep injection short to limit token overhead.
- Do not include full skill body in initial context.

### 4. Error handling
If `--skill` is passed and parsing fails:
- Print user-facing error and exit non-zero.

If parsing succeeds:
- Continue normal flow for all vendors.

### 5. Testing
Add tests:
- `test/test_skill.ml`:
  - parses minimal valid frontmatter (`name`, `description`)
  - parses optional fields (`license`, `compatibility`, `allowed-tools`)
  - parses simple `metadata` map
  - fails on missing delimiters
  - fails on missing `name` / `description`
- Update `test/test_suite.ml` to include skill parser tests.
- Add focused test for prompt augmentation (either in `test_skill.ml` or a new `test_prompt_context.ml`):
  - includes skill guidance text
  - includes frontmatter summary
  - preserves original prompt

### 6. Documentation
Update `README.md`:
- Add `--skill` / `-s` option and example.
- Explain V1 behavior (frontmatter injected, body read on demand via `read_file`).
- Clarify this is intentionally minimal and may evolve to full spec compliance.

## TODOs
- [ ] Add `--skill` / `-s` CLI option in `bin/main.ml`.
- [ ] Add `skill_path` to runtime params and pass through execution path.
- [ ] Create `lib/skill.ml` + `lib/skill.mli` with frontmatter parser + validation.
- [ ] Implement prompt augmentation helper for skill context injection.
- [ ] Wire skill parsing + prompt augmentation into run flow before agent call.
- [ ] Add parser and prompt-context tests.
- [ ] Register tests in `test/test_suite.ml`.
- [ ] Update `README.md` docs.

## Acceptance Criteria
- Running with `--skill path/to/SKILL.md` and valid frontmatter succeeds.
- Model receives additional context containing:
  - short instructions on skill usage,
  - parsed frontmatter,
  - instruction to read full `SKILL.md` via `read_file` when needed.
- Running with invalid/missing frontmatter fails early with clear error.
- Existing non-skill runs behave unchanged.
- Test suite passes.

## Out of Scope (V1)
- Multi-skill support.
- Full YAML spec compliance.
- Automatic body/resource loading.
- Enforcement of `allowed-tools`.
- Skill discovery/registry from directories.

## Future Work
- Add dedicated skill tools (`get_skill_frontmatter`, `read_skill_body`) so the model requests skill data explicitly via tool calls instead of receiving it in the initial prompt.
  - Pros: less prompt bloat, better traceability.
  - Cons: additional tool-call round trips.
- Inject an internal system/developer context message in vendor payload builders instead of rewriting the user prompt.
  - Pros: cleaner separation of user input vs runtime context, clearer instruction priority.
  - Cons: requires vendor-specific message-shape wiring.
- Implement two-stage orchestration in the agent loop:
  - Stage 1: provide user prompt + skill summaries.
  - Stage 2: when skill is needed, append full skill content and continue.
  - Pros: progressive disclosure, lower context cost.
  - Cons: more loop complexity.
- Introduce a first-class runtime context abstraction (beyond prompt strings), so skills and future context sources can be attached consistently.
  - Pros: cleaner architecture and reuse.
  - Cons: broader refactor.
