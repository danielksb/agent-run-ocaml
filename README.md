# Agent Run

Agent Run is a small OCaml CLI application that sends prompts to an LLM vendor (currently `openai`, `gemini` and `ollama`), supports tool calls, and prints the final model response to stdout.

The primary goal of this project is to learn OCaml and play around with different LLM APIs. The runner is suppose to be small enough to be used in shell scripts.

Future versions might publish the library component in order to use it in other projects.

## Built-in Tools

- `list_files`
- `read_file`
- `write_file`
- `exec_program`: executes a program via `Unix.execvpe` and returns:
  - `status code: <n>`
  - combined stdout/stderr output
- `fetch_url`: performs an HTTP(S) GET request and returns the response body as text

`exec_program` can run any executable available in `PATH`. This is powerful but high-risk; only use it in trusted environments.

## How To Run

Build and run with `dune exec`:

```shell
dune exec -- agent-run --vendor ollama --prompt "What is the current temperature in Berlin in Celsius?"
```

You can also choose a specific model:

```shell
dune exec -- agent-run --vendor openai --model gpt-4.1-mini --prompt "What is the capital of Germany?"
```

You can provide a skill file:

```shell
dune exec -- agent-run --vendor openai --skill ./my-skill/SKILL.md --prompt "Help me process PDFs"
```

When `--skill`/`-s` is used, Agent Run parses the SKILL frontmatter and injects it into the initial request context with instructions to read the full `SKILL.md` through `read_file` if detailed instructions are needed.
You can provide `--skill` multiple times to attach more than one skill.

Set credentials when needed:

- `OPENAI_API_KEY` for `--vendor openai`
- `GEMINI_API_KEY` for `--vendor gemini`

## Configuration File

Agent Run can load a TOML config file via `--config /path/to/config.toml`.
If `--config` is not provided, it will try `~/.agent-run.toml`.

All vendor sections are optional:

```toml
[openai]
model = "gpt-4.1-mini"
base_url = "https://api.openai.com"

[gemini]
model = "gemini-2.5-flash"
base_url = "https://generativelanguage.googleapis.com"

[ollama]
base_url = "http://localhost:11434"
model = "functiongemma"
```

Model precedence is:
1. `--model` / `-m`
2. vendor `model` from config
3. built-in defaults (`gpt-4o-mini`, `gemini-flash-latest`, `functiongemma`)

Base URL precedence is:
1. `--base-url` / `-b`
2. vendor `base_url` from config
3. built-in defaults (`https://api.openai.com`, `https://generativelanguage.googleapis.com`, `http://localhost:11434`)

## Running Ollama

```shell
ollama run functiongemma
```

```shell
dune exec -- agent-run --vendor ollama --model functiongemma --prompt "List all files in the directory 'test'."
```

## Running with Skills

```shell
dune exec -- agent-run --vendor openai --skill .\playwright-cli.skill.md --verbose --prompt "go to duckduckgo.com, search for '!wiki Ocaml' and return a summary of the result"
```
