# Feature: `exec_program` Tool

## Goal
Add a new tool that executes a program with command-line parameters and returns one combined string in this format:

`status code: {status}`
`{stdout and stderr combined}`

Execution must use `Unix.execvpe` so programs can be resolved through `PATH`.

## Tool Contract
- Tool name: `exec_program`
- Description: Execute a program with optional CLI arguments and return exit status and merged output.
- Input schema:
  - `program` (string, required): executable name or path.
  - `args` (array of strings, optional): command-line arguments provided by the LLM.
- Output:
  - Always `Ok string` from the tool handler when process launch succeeds.
  - String format:
    - First line: `status code: {status}`
    - Remaining lines: merged stdout/stderr content (preserve ordering as produced by the OS pipe).
  - Return `Error string` only for validation/launch failures (invalid argument types, `execvpe` failures before exec).

## Design Notes
- Use `Unix.fork` + `Unix.execvpe` in child.
- In child process:
  - Redirect both `stdout` and `stderr` to the same pipe write-end via `Unix.dup2`.
  - Build `argv` as `program :: args`.
  - Build environment array from current process environment.
  - Call `Unix.execvpe program argv envp`.
- In parent process:
  - Close write-end, read full content from read-end.
  - Wait for child using `Unix.waitpid`.
  - Convert wait status:
    - `WEXITED n` -> `n`
    - `WSIGNALED s` / `WSTOPPED s` -> non-zero mapping (document exact mapping in code and tests).
- Keep tool interface synchronous like existing tools (`Yojson.Safe.t -> (string, string) result`).

## Security and Limits (MVP)
- No shell invocation (`/bin/sh -c`) by default to avoid injection by design.
- Optional follow-up hardening (not required for first merge):
  - allow shell execution in config
  - timeout
  - max output size
  - working-directory sandboxing

## TODOs
- [x] Add new module `[lib/exec_program.ml](/C:/projects/private/agent-run-ocaml/lib/exec_program.ml)` with:
  - [x] `definition : Tool.t` including `program`, `args`
  - [x] JSON parsing/validation for `args` as string list
  - [x] process execution via `Unix.execvpe` (POSIX) with Windows-compatible fallback
  - [x] stdout+stderr merge through single pipe
  - [x] result formatting `status code: {status}` + combined output
- [x] Register tool in `[lib/tool_registry.ml](/C:/projects/private/agent-run-ocaml/lib/tool_registry.ml)` inside `all_tools`.
- [x] Update `[lib/dune](/C:/projects/private/agent-run-ocaml/lib/dune)` to include `unix` library dependency.
- [x] Add tests (new file `[test/test_exec_program.ml](/C:/projects/private/agent-run-ocaml/test/test_exec_program.ml)`):
  - [x] successful command returns `status code: 0`
  - [x] non-zero exit code is reported correctly
  - [x] stdout and stderr are both present in combined output
  - [x] argument list is passed correctly (platform-appropriate coverage)
  - [x] missing required `program` returns validation error
  - [x] wrong type for `args` returns validation error
- [x] Wire new tests into `[test/test_suite.ml](/C:/projects/private/agent-run-ocaml/test/test_suite.ml)`.
- [x] Documentation update in `[README.md](/C:/projects/private/agent-run-ocaml/README.md)`:
  - [x] mention new tool and expected output format
  - [x] clarify security implications of allowing command execution

## Acceptance Criteria
- Tool is discoverable via registry and exposed to all vendors.
- For a command that prints to both streams and exits with non-zero:
  - output begins with exact `status code: <n>` prefix
  - combined stream content includes both stdout and stderr text.
- Tool uses `Unix.execvpe` directly (not shell wrappers).
- All tests pass.
