# Agent Run


# Running Ollama

```shell
ollama run functiongemma
```

```bash
curl -vvv http://localhost:11434/api/chat -d '{"model": "functiongemma", "messages": [{ "role": "user", content: "What is the capital of Germany?"  }], "stream": false }'
```

```powershell
Invoke-RestMethod -Uri 'http://localhost:11434/api/chat' -Method Post -Body '{"model":"functiongemma","messages":[{"role":"user","content":"What is the capital of Germany?"}],"stream":false}' -ContentType 'application/json' -Verbose
```

```shell
opam exec dune exec -- agent-run -- --vendor ollama "Create a cron schedule string for 'every week day at 6:00 in the morning'. Respond with the cron schedule string only"
```
