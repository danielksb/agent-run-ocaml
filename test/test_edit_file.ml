open Agentlib

let string_result_testable = Alcotest.(result string string)

let make_temp_dir prefix =
  let path = Filename.temp_file prefix ".tmp" in
  Sys.remove path ;
  Unix.mkdir path 0o700 ;
  path

let write_text_file path content =
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out

let read_text_file path =
  let input = open_in path in
  Fun.protect
    (fun () -> In_channel.input_all input)
    ~finally:(fun () -> close_in_noerr input)

let with_cwd dir f =
  let old_cwd = Sys.getcwd () in
  Fun.protect
    (fun () ->
      Unix.chdir dir ;
      f () )
    ~finally:(fun () -> Unix.chdir old_cwd)

let test_edit_file_replaces_first_occurrence_only () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  let file_name = "inside.txt" in
  let inside_path = Filename.concat temp_cwd file_name in
  write_text_file inside_path "one two one" ;
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            Edit_file.run ~working_directory:temp_cwd
              (`Assoc
                 [ ("file", `String file_name)
                 ; ("old_string", `String "one")
                 ; ("new_string", `String "1")
                 ; ("replace_all", `Bool false) ] )
          in
          Alcotest.(check string_result_testable)
            "edit_file succeeds"
            (Ok ("File " ^ file_name ^ " was successfully written."))
            result ;
          let content = read_text_file inside_path in
          Alcotest.(check string)
            "only first occurrence replaced" "1 two one" content ) )
    ~finally:(fun () ->
      if Sys.file_exists inside_path then Sys.remove inside_path ;
      if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd )

let test_edit_file_replaces_all_occurrences () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  let file_name = "inside.txt" in
  let inside_path = Filename.concat temp_cwd file_name in
  write_text_file inside_path "one two one" ;
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            Edit_file.run ~working_directory:temp_cwd
              (`Assoc
                 [ ("file", `String file_name)
                 ; ("old_string", `String "one")
                 ; ("new_string", `String "1")
                 ; ("replace_all", `Bool true) ] )
          in
          Alcotest.(check string_result_testable)
            "edit_file succeeds"
            (Ok ("File " ^ file_name ^ " was successfully written."))
            result ;
          let content = read_text_file inside_path in
          Alcotest.(check string)
            "all occurrences replaced" "1 two 1" content ) )
    ~finally:(fun () ->
      if Sys.file_exists inside_path then Sys.remove inside_path ;
      if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd )

let tests =
  ( "edit_file"
  , [ Alcotest.test_case "replace first occurrence" `Quick
        test_edit_file_replaces_first_occurrence_only
    ; Alcotest.test_case "replace all occurrences" `Quick
        test_edit_file_replaces_all_occurrences ] )
