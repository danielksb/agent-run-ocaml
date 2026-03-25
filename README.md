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
opam exec dune exec -- agent-run -- --vendor ollama --prompt "What is the current temperature in Berlin in Celsius?"
```
