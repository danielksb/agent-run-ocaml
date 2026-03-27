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

Set credentials when needed:

- `OPENAI_API_KEY` for `--vendor openai`
- `GEMINI_API_KEY` for `--vendor gemini`

## Running Ollama

```shell
ollama run functiongemma
```

```shell
dune exec -- agent-run --vendor ollama --model functiongemma --prompt "List all files in the directory 'test'."
```
