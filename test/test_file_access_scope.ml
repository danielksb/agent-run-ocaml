open Agentlib

let string_result_testable = Alcotest.(result string string)

let contains text pattern =
  let text_len = String.length text in
  let pattern_len = String.length pattern in
  let rec loop idx =
    if idx + pattern_len > text_len then false
    else if String.sub text idx pattern_len = pattern then true
    else loop (idx + 1)
  in
  if pattern_len = 0 then true else loop 0

let make_temp_dir prefix =
  let path = Filename.temp_file prefix ".tmp" in
  Sys.remove path ; Unix.mkdir path 0o700 ; path

let write_text_file path content =
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out

let with_cwd dir f =
  let old_cwd = Sys.getcwd () in
  Fun.protect
    (fun () -> Unix.chdir dir ; f ())
    ~finally:(fun () -> Unix.chdir old_cwd)

let test_read_file_denies_outside_cwd () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  let outside_file = Filename.temp_file "agent_run_outside_" ".txt" in
  write_text_file outside_file "outside" ;
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            Read_file.run ~working_directory:temp_cwd
              (`Assoc [("file", `String outside_file)])
          in
          match result with
          | Ok _ ->
              Alcotest.fail "read_file unexpectedly allowed outside file"
          | Error msg ->
              Alcotest.(check bool)
                "error mentions access denied" true
                (contains msg "Access denied") ) )
    ~finally:(fun () ->
      if Sys.file_exists outside_file then Sys.remove outside_file ;
      if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd )

let test_write_file_denies_outside_cwd () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  let outside_file = Filename.temp_file "agent_run_outside_" ".txt" in
  write_text_file outside_file "original" ;
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            Write_file.run ~working_directory:temp_cwd
              (`Assoc
                 [("file", `String outside_file); ("content", `String "new")] )
          in
          ( match result with
          | Ok _ ->
              Alcotest.fail "write_file unexpectedly allowed outside file"
          | Error msg ->
              Alcotest.(check bool)
                "error mentions access denied" true
                (contains msg "Access denied") ) ;
          let content =
            let input = open_in outside_file in
            Fun.protect
              (fun () -> In_channel.input_all input)
              ~finally:(fun () -> close_in_noerr input)
          in
          Alcotest.(check string)
            "outside file remains unchanged" "original" content ) )
    ~finally:(fun () ->
      if Sys.file_exists outside_file then Sys.remove outside_file ;
      if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd )

let test_list_files_denies_outside_cwd () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  let outside_dir = make_temp_dir "agent_run_outside_dir_" in
  let outside_file = Filename.concat outside_dir "x.txt" in
  write_text_file outside_file "x" ;
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            List_files.run ~working_directory:temp_cwd
              (`Assoc [("directory", `String outside_dir)])
          in
          match result with
          | Ok _ ->
              Alcotest.fail "list_files unexpectedly allowed outside directory"
          | Error msg ->
              Alcotest.(check bool)
                "error mentions access denied" true
                (contains msg "Access denied") ) )
    ~finally:(fun () ->
      if Sys.file_exists outside_file then Sys.remove outside_file ;
      if Sys.file_exists outside_dir then Unix.rmdir outside_dir ;
      if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd )

let test_write_and_read_file_inside_cwd_succeeds () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  let file_name = "inside.txt" in
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let write_result =
            Write_file.run ~working_directory:temp_cwd
              (`Assoc
                 [("file", `String file_name); ("content", `String "inside")] )
          in
          Alcotest.(check string_result_testable)
            "write inside cwd succeeds"
            (Ok ("File " ^ file_name ^ " was successfully written."))
            write_result ;
          let read_result =
            Read_file.run ~working_directory:temp_cwd
              (`Assoc [("file", `String file_name)])
          in
          Alcotest.(check string_result_testable)
            "read inside cwd succeeds" (Ok "inside") read_result ) )
    ~finally:(fun () ->
      let inside_path = Filename.concat temp_cwd file_name in
      if Sys.file_exists inside_path then Sys.remove inside_path ;
      if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd )

let test_read_file_missing_file_returns_error () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            Read_file.run ~working_directory:temp_cwd
              (`Assoc [("file", `String "does-not-exist.txt")])
          in
          match result with
          | Ok _ ->
              Alcotest.fail "read_file unexpectedly succeeded for missing file"
          | Error msg ->
              Alcotest.(check string)
                "missing-file returns resolve error"
                "Cannot read file: does-not-exist.txt" msg ) )
    ~finally:(fun () -> if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd)

let test_write_file_missing_parent_returns_error () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            Write_file.run ~working_directory:temp_cwd
              (`Assoc
                 [ ("file", `String "missing\\dir\\file.txt")
                 ; ("content", `String "x") ] )
          in
          match result with
          | Ok _ ->
              Alcotest.fail
                "write_file unexpectedly succeeded with missing parent"
          | Error msg ->
              Alcotest.(check bool)
                "missing-parent returns resolve error" true
                (contains msg "Cannot resolve path") ) )
    ~finally:(fun () -> if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd)

let test_read_file_uses_configured_guard_root () =
  let temp_cwd = make_temp_dir "agent_run_cwd_" in
  let temp_root = make_temp_dir "agent_run_root_" in
  let inside_root_file = Filename.concat temp_root "inside.txt" in
  write_text_file inside_root_file "inside-root" ;
  Fun.protect
    (fun () ->
      with_cwd temp_cwd (fun () ->
          let result =
            Read_file.run ~working_directory:temp_root
              (`Assoc [("file", `String inside_root_file)])
          in
          Alcotest.(check string_result_testable)
            "read_file allows path in configured root"
            (Ok "inside-root") result ) )
    ~finally:(fun () ->
      if Sys.file_exists inside_root_file then Sys.remove inside_root_file ;
      if Sys.file_exists temp_root then Unix.rmdir temp_root ;
      if Sys.file_exists temp_cwd then Unix.rmdir temp_cwd )

let tests =
  ( "file_access_scope"
  , [ Alcotest.test_case "read_file denies outside cwd" `Quick
        test_read_file_denies_outside_cwd
    ; Alcotest.test_case "write_file denies outside cwd" `Quick
        test_write_file_denies_outside_cwd
    ; Alcotest.test_case "list_files denies outside cwd" `Quick
        test_list_files_denies_outside_cwd
    ; Alcotest.test_case "inside cwd read/write succeeds" `Quick
        test_write_and_read_file_inside_cwd_succeeds
    ; Alcotest.test_case "read_file missing file returns error" `Quick
        test_read_file_missing_file_returns_error
    ; Alcotest.test_case "write_file missing parent returns error" `Quick
        test_write_file_missing_parent_returns_error
    ; Alcotest.test_case "read_file uses configured guard root" `Quick
        test_read_file_uses_configured_guard_root ] )
