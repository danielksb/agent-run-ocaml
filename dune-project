(lang dune 3.22)

(name agent-run)

(generate_opam_files true)

(source
 (github danielksb/agent-run-ocaml))

(authors "Daniel Kuschel <danielkaes@duck.com>")

(maintainers "Daniel Kuschel <danielkaes@duck.com>")

(license Apache-2.0)

(documentation https://github.com/danielksb/agent-run-ocaml)

(package
 (name agent-run)
 (synopsis "CLI-based LLM agent runner")
 (description "CLI-based LLM agent runner supporting OpenAI and Gemini APIs")
 (depends
  (ocaml (>= 5.3))
  (cohttp-lwt-unix (>= 6.2))
  base-unix
  (ppx_deriving_yojson (>= 3.10))
  toml
  (alcotest :with-test)
  (bisect_ppx (and :with-test (< ocaml 5.4))))
 (tags
  ("ai" "cli" "llm")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
