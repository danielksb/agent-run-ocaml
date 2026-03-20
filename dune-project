(lang dune 3.21)

(name agent-run)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Daniel Kuschel")

(maintainers "Daniel Kuschel")

(license LICENSE)

(documentation https://github.com/danielksb/agent-run-ocaml)

(package
 (name agent-run)
 (synopsis "CLI-based LLM agent runner")
 (description "CLI-based LLM agent runner supporting OpenAI and Gemini APIs")
 (depends
  (ocaml (>= 5.4))
  (ppx_deriving_yojson (>= 3.10))
  toml
  (alcotest :with-test))
 (tags
  ("ai" "cli" "llm")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
