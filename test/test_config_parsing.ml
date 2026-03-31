open Agentlib

let with_temp_config content f =
  let path = Filename.temp_file "agent_run_config_" ".toml" in
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out ;
  Fun.protect
    (fun () -> f path)
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)

let with_temp_dir f =
  let base = Filename.get_temp_dir_name () in
  let rec make_dir n =
    let path =
      Filename.concat base (Printf.sprintf "agent_run_test_home_%d" n)
    in
    if Sys.file_exists path then make_dir (n + 1)
    else (Unix.mkdir path 0o700 ; path)
  in
  let rec rm_tree path =
    if Sys.file_exists path then
      if Sys.is_directory path then (
        Sys.readdir path
        |> Array.iter (fun name -> rm_tree (Filename.concat path name)) ;
        Unix.rmdir path )
      else Sys.remove path
  in
  let dir = make_dir 0 in
  Fun.protect (fun () -> f dir) ~finally:(fun () -> rm_tree dir)

let with_env_vars vars f =
  let snapshot = List.map (fun key -> (key, Sys.getenv_opt key)) vars in
  Fun.protect
    (fun () -> f ())
    ~finally:(fun () ->
      List.iter
        (fun (key, value_opt) ->
          match value_opt with
          | Some value ->
              Unix.putenv key value
          | None ->
              Unix.putenv key "" )
        snapshot )

let expect_raises name fn =
  try
    let _ = fn () in
    Alcotest.fail (name ^ ": expected exception")
  with _ -> ()

let test_empty_config_uses_defaults () =
  with_temp_config "" (fun path ->
      let config = Config.load (Some path) in
      Alcotest.(check string)
        "openai model default kept" "gpt-4o-mini" config.openai.model ;
      Alcotest.(check string)
        "openai base_url default kept" "https://api.openai.com"
        config.openai.base_url ;
      Alcotest.(check string)
        "gemini model default kept" "gemini-flash-latest" config.gemini.model ;
      Alcotest.(check string)
        "gemini base_url default kept"
        "https://generativelanguage.googleapis.com" config.gemini.base_url ;
      Alcotest.(check string)
        "ollama model default kept" "functiongemma" config.ollama.model ;
      Alcotest.(check string)
        "ollama base_url default kept" "http://localhost:11434"
        config.ollama.base_url )

let test_parse_all_vendor_models () =
  let content =
    String.concat "\n"
      [ "[openai]"
      ; "model = \"gpt-4.1-mini\""
      ; "base_url = \"https://api.openai.com\""
      ; ""
      ; "[gemini]"
      ; "model = \"gemini-2.5-flash\""
      ; "base_url = \"https://generativelanguage.googleapis.com\""
      ; ""
      ; "[ollama]"
      ; "base_url = \"http://127.0.0.1:11434\""
      ; "model = \"my-ollama-model\"" ]
  in
  with_temp_config content (fun path ->
      let config = Config.load (Some path) in
      Alcotest.(check string)
        "openai model parsed" "gpt-4.1-mini" config.openai.model ;
      Alcotest.(check string)
        "openai base_url parsed" "https://api.openai.com" config.openai.base_url ;
      Alcotest.(check string)
        "gemini model parsed" "gemini-2.5-flash" config.gemini.model ;
      Alcotest.(check string)
        "gemini base_url parsed" "https://generativelanguage.googleapis.com"
        config.gemini.base_url ;
      Alcotest.(check string)
        "ollama model parsed" "my-ollama-model" config.ollama.model ;
      Alcotest.(check string)
        "ollama base_url parsed" "http://127.0.0.1:11434" config.ollama.base_url )

let test_partial_config_does_not_change_other_vendor_defaults () =
  let content =
    String.concat "\n"
      [ "[openai]"
      ; "model = \"gpt-4.1\""
      ; "base_url = \"https://api.openai.com\"" ]
  in
  with_temp_config content (fun path ->
      let config = Config.load (Some path) in
      Alcotest.(check string) "openai model set" "gpt-4.1" config.openai.model ;
      Alcotest.(check string)
        "openai base_url set" "https://api.openai.com" config.openai.base_url ;
      Alcotest.(check string)
        "gemini model still default" "gemini-flash-latest" config.gemini.model ;
      Alcotest.(check string)
        "gemini base_url still default"
        "https://generativelanguage.googleapis.com" config.gemini.base_url ;
      Alcotest.(check string)
        "ollama model still default" "functiongemma" config.ollama.model ;
      Alcotest.(check string)
        "ollama base_url still default" "http://localhost:11434"
        config.ollama.base_url )

let test_load_none_without_default_file_uses_defaults () =
  with_temp_dir (fun dir ->
      with_env_vars ["HOME"; "USERPROFILE"] (fun () ->
          Unix.putenv "HOME" dir ;
          Unix.putenv "USERPROFILE" "" ;
          let config = Config.load None in
          Alcotest.(check string)
            "openai model default" "gpt-4o-mini" config.openai.model ;
          Alcotest.(check string)
            "openai base_url default" "https://api.openai.com"
            config.openai.base_url ;
          Alcotest.(check string)
            "gemini model default" "gemini-flash-latest" config.gemini.model ;
          Alcotest.(check string)
            "gemini base_url default"
            "https://generativelanguage.googleapis.com" config.gemini.base_url ;
          Alcotest.(check string)
            "ollama model default" "functiongemma" config.ollama.model ;
          Alcotest.(check string)
            "ollama base_url default" "http://localhost:11434"
            config.ollama.base_url ) )

let test_load_none_reads_default_file_from_home () =
  with_temp_dir (fun dir ->
      with_env_vars ["HOME"; "USERPROFILE"] (fun () ->
          Unix.putenv "HOME" dir ;
          Unix.putenv "USERPROFILE" "" ;
          let path = Filename.concat dir ".agent-run.toml" in
          let content =
            String.concat "\n"
              [ "[openai]"
              ; "model = \"test-openai\""
              ; "base_url = \"https://openai.example\""
              ; ""
              ; "[gemini]"
              ; "model = \"test-gemini\""
              ; "base_url = \"https://gemini.example\""
              ; ""
              ; "[ollama]"
              ; "model = \"test-ollama\""
              ; "base_url = \"http://ollama.example:11434\"" ]
          in
          let out = open_out path in
          Out_channel.output_string out content ;
          close_out out ;
          let config = Config.load None in
          Alcotest.(check string)
            "openai model loaded" "test-openai" config.openai.model ;
          Alcotest.(check string)
            "openai base_url loaded" "https://openai.example"
            config.openai.base_url ;
          Alcotest.(check string)
            "gemini model loaded" "test-gemini" config.gemini.model ;
          Alcotest.(check string)
            "gemini base_url loaded" "https://gemini.example"
            config.gemini.base_url ;
          Alcotest.(check string)
            "ollama model loaded" "test-ollama" config.ollama.model ;
          Alcotest.(check string)
            "ollama base_url loaded" "http://ollama.example:11434"
            config.ollama.base_url ) )

let test_invalid_toml_raises () =
  let content = "[openai\nmodel = \"x\"" in
  with_temp_config content (fun path ->
      expect_raises "invalid toml should raise" (fun () ->
          Config.load (Some path) ) )

let test_missing_explicit_path_raises () =
  let path =
    Filename.concat (Filename.get_temp_dir_name ()) "does_not_exist.toml"
  in
  expect_raises "missing explicit path should raise" (fun () ->
      Config.load (Some path) )

let tests =
  ( "config_parsing"
  , [ Alcotest.test_case "empty config uses defaults" `Quick
        test_empty_config_uses_defaults
    ; Alcotest.test_case "parse all vendor models" `Quick
        test_parse_all_vendor_models
    ; Alcotest.test_case "partial config keeps defaults" `Quick
        test_partial_config_does_not_change_other_vendor_defaults
    ; Alcotest.test_case "load none without default file uses defaults" `Quick
        test_load_none_without_default_file_uses_defaults
    ; Alcotest.test_case "load none reads default file from home" `Quick
        test_load_none_reads_default_file_from_home
    ; Alcotest.test_case "invalid toml raises" `Quick test_invalid_toml_raises
    ; Alcotest.test_case "missing explicit path raises" `Quick
        test_missing_explicit_path_raises ] )
