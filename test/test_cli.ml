open Agentlib

let with_temp_config content f =
  let path = Filename.temp_file "agent_run_cli_config_" ".toml" in
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out ;
  Fun.protect
    (fun () -> f path)
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)

let with_temp_skill_file content f =
  let path = Filename.temp_file "agent_run_cli_skill_" ".md" in
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out ;
  Fun.protect
    (fun () -> f path)
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)

let with_temp_dir f =
  let base = Filename.get_temp_dir_name () in
  let rec make_dir n =
    let path = Filename.concat base (Printf.sprintf "agent_run_cli_dir_%d" n) in
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

let cli_from_mock mock =
  let module Platform = (val Mock_platform.to_platform mock : Cli.PLATFORM) in
  let module CliImpl = Cli.Make (Platform) in
  (module CliImpl : Cli.S)

let result_or_fail = function
  | Ok x ->
      x
  | Error msg ->
      Alcotest.failf "expected Ok, got Error: %s" (Cli.cli_msg_to_string msg)

let expect_error expected = function
  | Error actual when actual = expected ->
      ()
  | Error actual ->
      Alcotest.failf "expected Error(%s), got Error(%s)"
        (Cli.cli_msg_to_string expected)
        (Cli.cli_msg_to_string actual)
  | Ok _ ->
      Alcotest.failf "expected Error(%s), got Ok"
        (Cli.cli_msg_to_string expected)

let expect_load_skill_failed = function
  | Error (Cli.LoadSkillFailed _) ->
      ()
  | Error actual ->
      Alcotest.failf "expected Error(LoadSkillFailed ...), got Error(%s)"
        (Cli.cli_msg_to_string actual)
  | Ok _ ->
      Alcotest.failf "expected Error(LoadSkillFailed ...), got Ok"

let argv_with_config config_path args =
  Array.of_list ("agent-run" :: "--config" :: config_path :: args)

let run_create_agent_config ?(cwd = "C:\\mock-cwd") ?(stdin = "") ?(env = [])
    ?(files = []) ?regular_files argv =
  let mock =
    Mock_platform.create ~argv ~cwd ~stdin ~env ~files ?regular_files ()
  in
  let module CliImpl = (val cli_from_mock mock : Cli.S) in
  CliImpl.create_agent_config ()

let contains text pattern =
  let text_len = String.length text in
  let pattern_len = String.length pattern in
  let rec loop i =
    if i + pattern_len > text_len then false
    else if String.sub text i pattern_len = pattern then true
    else loop (i + 1)
  in
  if pattern_len = 0 then true else loop 0

let test_help_returns_usage () =
  with_temp_config "" (fun config_path ->
      let argv = argv_with_config config_path ["--help"] in
      run_create_agent_config argv |> expect_error Cli.Usage )

let test_no_prompt_returns_error () =
  with_temp_config "" (fun config_path ->
      let argv = argv_with_config config_path [] in
      run_create_agent_config argv |> expect_error Cli.NoPrompt )

let test_unknown_vendor_returns_error () =
  with_temp_config "" (fun config_path ->
      let argv =
        argv_with_config config_path
          ["--prompt"; "hello"; "--vendor"; "unknown-vendor"]
      in
      run_create_agent_config argv
      |> expect_error (Cli.UnknownVendor "unknown-vendor") )

let test_missing_openai_api_key_returns_error () =
  with_temp_config "" (fun config_path ->
      let argv =
        argv_with_config config_path ["--prompt"; "hello"; "--vendor"; "openai"]
      in
      run_create_agent_config argv
      |> expect_error (Cli.NoApiKey "OPENAI_API_KEY") )

let test_missing_gemini_api_key_returns_error () =
  with_temp_config "" (fun config_path ->
      let argv =
        argv_with_config config_path ["--prompt"; "hello"; "--vendor"; "gemini"]
      in
      run_create_agent_config argv
      |> expect_error (Cli.NoApiKey "GEMINI_API_KEY") )

let test_ollama_without_api_key_is_ok () =
  with_temp_config "" (fun config_path ->
      let argv =
        argv_with_config config_path ["--prompt"; "hello"; "--vendor"; "ollama"]
      in
      let result =
        run_create_agent_config ~cwd:"C:\\workspace" argv |> result_or_fail
      in
      Alcotest.(check string)
        "ollama allows missing key" "" result.agent_config.api_key ;
      Alcotest.(check string)
        "cwd used as fallback working directory" "C:\\workspace"
        result.agent_config.tool_context.working_directory ;
      Alcotest.(check string)
        "default ollama model loaded from config defaults" "gemma4:e2b"
        result.agent_config.model_name ;
      Alcotest.(check (of_pp (fun fmt v -> Format.pp_print_string fmt v)))
        "vendor is ollama" "ollama"
        ( match result.vendor with
        | Cli.Ollama ->
            "ollama"
        | Cli.OpenAi ->
            "openai"
        | Cli.Gemini ->
            "gemini" ) )

let test_prompt_can_be_read_from_stdin () =
  with_temp_config "" (fun config_path ->
      let argv =
        argv_with_config config_path ["--prompt"; "-"; "--vendor"; "openai"]
      in
      let result =
        run_create_agent_config ~stdin:"prompt from stdin"
          ~env:[("OPENAI_API_KEY", "test-key")]
          argv
        |> result_or_fail
      in
      Alcotest.(check string)
        "stdin prompt used" "prompt from stdin" result.prompt )

let test_prompt_file_content_is_used_when_prompt_arg_is_file_path () =
  with_temp_config "" (fun config_path ->
      let prompt_path = "prompt.txt" in
      let argv =
        argv_with_config config_path
          ["--prompt"; prompt_path; "--vendor"; "openai"]
      in
      let result =
        run_create_agent_config
          ~files:[(prompt_path, "prompt from file")]
          ~env:[("OPENAI_API_KEY", "test-key")]
          argv
        |> result_or_fail
      in
      Alcotest.(check string)
        "file prompt used" "prompt from file" result.prompt )

let test_prompt_path_that_is_not_regular_file_is_used_verbatim () =
  with_temp_config "" (fun config_path ->
      let prompt_path = "prompt.txt" in
      let argv =
        argv_with_config config_path
          ["--prompt"; prompt_path; "--vendor"; "openai"]
      in
      let result =
        run_create_agent_config ~regular_files:[]
          ~env:[("OPENAI_API_KEY", "test-key")]
          argv
        |> result_or_fail
      in
      Alcotest.(check string)
        "non-regular-file prompt is used verbatim" prompt_path result.prompt )

let test_working_directory_cli_overrides_config () =
  let config =
    String.concat "\n" ["working_directory = \"C:\\\\from-config\""]
  in
  with_temp_config config (fun config_path ->
      let argv =
        argv_with_config config_path
          [ "--prompt"
          ; "hello"
          ; "--vendor"
          ; "openai"
          ; "--working-directory"
          ; "C:\\from-cli" ]
      in
      let result =
        run_create_agent_config ~cwd:"C:\\from-cwd"
          ~env:[("OPENAI_API_KEY", "test-key")]
          argv
        |> result_or_fail
      in
      Alcotest.(check string)
        "cli working directory has highest precedence" "C:\\from-cli"
        result.agent_config.tool_context.working_directory )

let test_working_directory_from_config_is_used_when_cli_missing () =
  let config =
    String.concat "\n" ["working_directory = \"C:\\\\from-config\""]
  in
  with_temp_config config (fun config_path ->
      let argv =
        argv_with_config config_path ["--prompt"; "hello"; "--vendor"; "openai"]
      in
      let result =
        run_create_agent_config ~cwd:"C:\\from-cwd"
          ~env:[("OPENAI_API_KEY", "test-key")]
          argv
        |> result_or_fail
      in
      Alcotest.(check string)
        "config working directory used when cli arg missing" "C:\\from-config"
        result.agent_config.tool_context.working_directory )

let test_model_and_base_url_cli_overrides_vendor_config () =
  let config =
    String.concat "\n"
      [ "[openai]"
      ; "model = \"config-model\""
      ; "base_url = \"https://config.openai.example\"" ]
  in
  with_temp_config config (fun config_path ->
      let argv =
        argv_with_config config_path
          [ "--prompt"
          ; "hello"
          ; "--vendor"
          ; "openai"
          ; "--model"
          ; "cli-model"
          ; "--base-url"
          ; "https://cli.openai.example" ]
      in
      let result =
        run_create_agent_config ~env:[("OPENAI_API_KEY", "test-key")] argv
        |> result_or_fail
      in
      Alcotest.(check string)
        "model override applied" "cli-model" result.agent_config.model_name ;
      Alcotest.(check string)
        "base_url override applied" "https://cli.openai.example"
        result.agent_config.base_url )

let test_missing_skill_file_returns_load_skill_failed () =
  with_temp_config "" (fun config_path ->
      let argv =
        argv_with_config config_path
          [ "--prompt"
          ; "hello"
          ; "--vendor"
          ; "openai"
          ; "--skill"
          ; "does-not-exist/SKILL.md" ]
      in
      run_create_agent_config ~cwd:"C:\\workspace"
        ~env:[("OPENAI_API_KEY", "test-key")]
        argv
      |> expect_load_skill_failed )

let test_relative_skill_path_is_resolved_from_cwd () =
  with_temp_dir (fun cwd ->
      let skill_file = Filename.concat cwd "SKILL.md" in
      let skill_content =
        String.concat "\n"
          [ "---"
          ; "name: relative-skill"
          ; "description: loaded via cwd"
          ; "---"
          ; "body" ]
      in
      let out = open_out skill_file in
      Out_channel.output_string out skill_content ;
      close_out out ;
      with_temp_config "" (fun config_path ->
          let argv =
            argv_with_config config_path
              ["--prompt"; "hello"; "--vendor"; "openai"; "--skill"; "SKILL.md"]
          in
          let result =
            run_create_agent_config ~cwd
              ~env:[("OPENAI_API_KEY", "test-key")]
              argv
            |> result_or_fail
          in
          Alcotest.(check bool)
            "relative skill frontmatter added to prompt" true
            (contains result.prompt "name: relative-skill") ) )

let test_multiple_skill_files_are_loaded_and_frontmatter_is_added_to_prompt () =
  let skill_one =
    String.concat "\n"
      [ "---"
      ; "name: skill-one"
      ; "description: first skill description"
      ; "---"
      ; "body one" ]
  in
  let skill_two =
    String.concat "\n"
      [ "---"
      ; "name: skill-two"
      ; "description: second skill description"
      ; "---"
      ; "body two" ]
  in
  with_temp_skill_file skill_one (fun skill_path_one ->
      with_temp_skill_file skill_two (fun skill_path_two ->
          with_temp_config "" (fun config_path ->
              let user_prompt = "summarize repository status" in
              let argv =
                argv_with_config config_path
                  [ "--prompt"
                  ; user_prompt
                  ; "--vendor"
                  ; "openai"
                  ; "--skill"
                  ; skill_path_one
                  ; "--skill"
                  ; skill_path_two ]
              in
              let result =
                run_create_agent_config
                  ~env:[("OPENAI_API_KEY", "test-key")]
                  argv
                |> result_or_fail
              in
              let prompt = result.prompt in
              Alcotest.(check bool)
                "contains first skill name" true
                (contains prompt "name: skill-one") ;
              Alcotest.(check bool)
                "contains first skill description" true
                (contains prompt "description: first skill description") ;
              Alcotest.(check bool)
                "contains second skill name" true
                (contains prompt "name: skill-two") ;
              Alcotest.(check bool)
                "contains second skill description" true
                (contains prompt "description: second skill description") ;
              Alcotest.(check bool)
                "contains user prompt marker" true
                (contains prompt "User prompt:") ;
              Alcotest.(check bool)
                "ends with original user prompt" true
                (String.ends_with ~suffix:user_prompt prompt) ) ) )

let tests =
  ( "cli"
  , [ Alcotest.test_case "help returns usage" `Quick test_help_returns_usage
    ; Alcotest.test_case "no prompt returns error" `Quick
        test_no_prompt_returns_error
    ; Alcotest.test_case "unknown vendor returns error" `Quick
        test_unknown_vendor_returns_error
    ; Alcotest.test_case "missing openai api key returns error" `Quick
        test_missing_openai_api_key_returns_error
    ; Alcotest.test_case "missing gemini api key returns error" `Quick
        test_missing_gemini_api_key_returns_error
    ; Alcotest.test_case "ollama without api key is ok" `Quick
        test_ollama_without_api_key_is_ok
    ; Alcotest.test_case "stdin prompt is used" `Quick
        test_prompt_can_be_read_from_stdin
    ; Alcotest.test_case "prompt file path loads file content" `Quick
        test_prompt_file_content_is_used_when_prompt_arg_is_file_path
    ; Alcotest.test_case "non-regular prompt path is used verbatim" `Quick
        test_prompt_path_that_is_not_regular_file_is_used_verbatim
    ; Alcotest.test_case "working directory cli overrides config" `Quick
        test_working_directory_cli_overrides_config
    ; Alcotest.test_case "working directory from config is used" `Quick
        test_working_directory_from_config_is_used_when_cli_missing
    ; Alcotest.test_case "model and base_url cli override config" `Quick
        test_model_and_base_url_cli_overrides_vendor_config
    ; Alcotest.test_case "missing skill file returns load-skill-failed" `Quick
        test_missing_skill_file_returns_load_skill_failed
    ; Alcotest.test_case "relative skill path resolves from cwd" `Quick
        test_relative_skill_path_is_resolved_from_cwd
    ; Alcotest.test_case
        "multiple skill files are loaded and frontmatter is added to prompt"
        `Quick
        test_multiple_skill_files_are_loaded_and_frontmatter_is_added_to_prompt
    ] )
