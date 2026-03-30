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

let command_for_simple_output () =
  if Sys.win32 then
    ("powershell.exe", ["-NoProfile"; "-Command"; "Write-Output hello"])
  else ("sh", ["-c"; "echo hello"])

let command_for_mixed_streams_nonzero () =
  if Sys.win32 then
    ( "powershell.exe"
    , [ "-NoProfile"
      ; "-Command"
      ; "Write-Output out; [Console]::Error.WriteLine('err'); exit 7" ] )
  else ("sh", ["-c"; "echo out; echo err 1>&2; exit 7"])

let command_for_argument_echo value =
  if Sys.win32 then ("cmd.exe", ["/c"; "echo"; value])
  else ("sh", ["-c"; "printf '%s\\n' \"$1\""; "ignored-zero"; value])

let run_exec program args =
  Exec_program.run
    (`Assoc
       [ ("program", `String program)
       ; ("args", `List (List.map (fun s -> `String s) args)) ] )

let test_success_exit_code_zero () =
  let program, args = command_for_simple_output () in
  let result = run_exec program args in
  let output =
    match result with
    | Ok out ->
        out
    | Error e ->
        Alcotest.fail ("exec_program should succeed, got error: " ^ e)
  in
  Alcotest.(check bool)
    "status code is zero" true
    (contains output "status code: 0") ;
  Alcotest.(check bool) "stdout is present" true (contains output "hello")

let test_nonzero_exit_and_combined_streams () =
  let program, args = command_for_mixed_streams_nonzero () in
  let result = run_exec program args in
  let output =
    match result with
    | Ok out ->
        out
    | Error e ->
        Alcotest.fail ("exec_program should succeed, got error: " ^ e)
  in
  Alcotest.(check bool)
    "non-zero status reported" true
    (contains output "status code: 7") ;
  Alcotest.(check bool) "stdout is present" true (contains output "out") ;
  Alcotest.(check bool) "stderr is present" true (contains output "err")

let test_argument_list_passed () =
  let arg = if Sys.win32 then "hello-token-value" else "hello spaced value" in
  let program, args = command_for_argument_echo arg in
  let result = run_exec program args in
  let output =
    match result with
    | Ok out ->
        out
    | Error e ->
        Alcotest.fail ("exec_program should succeed, got error: " ^ e)
  in
  Alcotest.(check bool) "argument value preserved" true (contains output arg)

let test_missing_program_validation_error () =
  let result = Exec_program.run (`Assoc [("args", `List [`String "x"])]) in
  Alcotest.(check string_result_testable)
    "missing required program is rejected"
    (Error "missing required argument: program") result

let test_wrong_args_type_validation_error () =
  let result =
    Exec_program.run
      (`Assoc [("program", `String "echo"); ("args", `String "not-a-list")])
  in
  Alcotest.(check string_result_testable)
    "wrong args type is rejected"
    (Error
       "Cannot call tool 'exec_program': argument 'args' must be an array of \
        strings" )
    result

let tests =
  ( "exec_program"
  , [ Alcotest.test_case "success status zero" `Quick test_success_exit_code_zero
    ; Alcotest.test_case "non-zero + combined streams" `Quick
        test_nonzero_exit_and_combined_streams
    ; Alcotest.test_case "argument passing" `Quick test_argument_list_passed
    ; Alcotest.test_case "missing required argument" `Quick
        test_missing_program_validation_error
    ; Alcotest.test_case "wrong args type" `Quick
        test_wrong_args_type_validation_error ] )
