# Agent Run

Agent Run is a small OCaml CLI application that sends prompts to an LLM vendor (currently `openai`, `gemini` and `ollama`), supports tool calls, and prints the final model response to stdout.

The primary goal of this project is to learn OCaml and play around with different LLM APIs. The runner is supposed to be small enough to be used in shell scripts.

Future versions might publish the library component in order to use it in other projects.

## Built-in Tools

- `list_files`: lists files recursively in a given directory
- `read_file`: reads file content
- `write_file`: writes a string to a file
- `edit_file`: replaces strings in a file
- `exec_command`: executes a shell command and returns:
  - `status code: <n>`
  - combined stdout/stderr output
- `fetch_url`: performs an HTTP(S) GET request and returns the response body as text

`exec_command` runs via `sh -c` on Linux/macOS and PowerShell `Invoke-Expression` on Windows. This is powerful but high-risk; only use it in trusted environments.

## Security

Agent Run includes a built-in guard for file tools. `list_files`, `read_file`, and `write_file` are restricted to the configured working directory, and paths outside that root are denied.

For safer runs, explicitly define and restrict the working directory to the smallest required scope:
- CLI: `--working-directory <path>`
- Config: `working_directory = "/path/to/safe/root"`

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
model = "gemma4:e2b"
```

Model precedence is:
1. `--model` / `-m`
2. vendor `model` from config
3. built-in defaults (`gpt-4o-mini`, `gemini-flash-latest`, `gemma4:e2b`)

Base URL precedence is:
1. `--base-url` / `-b`
2. vendor `base_url` from config
3. built-in defaults (`https://api.openai.com`, `https://generativelanguage.googleapis.com`, `http://localhost:11434`)

## Running Ollama

```shell
ollama run gemma4:e2b
```

```shell
dune exec -- agent-run --vendor ollama --model gemma4:e2b --prompt "List all files in the directory 'test'."
```

## Running with Skills

```shell
dune exec -- agent-run --vendor openai --skill .\skills\playwright-cli.md --verbose --prompt "go to https://demo.playwright.dev/todomvc/, enter the TODO 'Learn OCaml' and make a snapshot"
```


```shell
dune exec -- agent-run --vendor gemini --skill .\skills\caveman.md --prompt "Use caveman skill. Describe the history of Germany since WW2. Put the result into output.txt. Open the file in notepad"
```
