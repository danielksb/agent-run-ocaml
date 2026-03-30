open Agentlib

let with_temp_config content f =
  let path = Filename.temp_file "agent_run_config_" ".toml" in
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out ;
  Fun.protect
    (fun () -> f path)
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)

let test_empty_config_uses_defaults () =
  with_temp_config "" (fun path ->
      let config = Config.load (Some path) in
      Alcotest.(check (option string))
        "openai model defaults to none" None config.openai.model ;
      Alcotest.(check (option string))
        "gemini model defaults to none" None config.gemini.model ;
      Alcotest.(check (option string))
        "ollama model defaults to none" None config.ollama.model ;
      Alcotest.(check string)
        "ollama url default kept"
        "http://localhost:11434" config.ollama.url )

let test_parse_all_vendor_models () =
  let content =
    String.concat "\n"
      [ "[openai]"
      ; "model = \"gpt-4.1-mini\""
      ; ""
      ; "[gemini]"
      ; "model = \"gemini-2.5-flash\""
      ; ""
      ; "[ollama]"
      ; "url = \"http://127.0.0.1:11434\""
      ; "model = \"my-ollama-model\"" ]
  in
  with_temp_config content (fun path ->
      let config = Config.load (Some path) in
      Alcotest.(check (option string))
        "openai model parsed" (Some "gpt-4.1-mini") config.openai.model ;
      Alcotest.(check (option string))
        "gemini model parsed" (Some "gemini-2.5-flash") config.gemini.model ;
      Alcotest.(check (option string))
        "ollama model parsed" (Some "my-ollama-model") config.ollama.model ;
      Alcotest.(check string)
        "ollama url parsed" "http://127.0.0.1:11434" config.ollama.url )

let test_partial_config_does_not_change_other_vendor_defaults () =
  let content =
    String.concat "\n" ["[openai]"; "model = \"gpt-4.1\""]
  in
  with_temp_config content (fun path ->
      let config = Config.load (Some path) in
      Alcotest.(check (option string))
        "openai model set" (Some "gpt-4.1") config.openai.model ;
      Alcotest.(check (option string))
        "gemini model still none" None config.gemini.model ;
      Alcotest.(check (option string))
        "ollama model still none" None config.ollama.model ;
      Alcotest.(check string)
        "ollama url still default"
        "http://localhost:11434" config.ollama.url )

let tests =
  ( "config_parsing"
  , [ Alcotest.test_case "empty config uses defaults" `Quick
        test_empty_config_uses_defaults
    ; Alcotest.test_case "parse all vendor models" `Quick
        test_parse_all_vendor_models
    ; Alcotest.test_case "partial config keeps defaults" `Quick
        test_partial_config_does_not_change_other_vendor_defaults ] )
