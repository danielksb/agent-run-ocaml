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
  if Sys.win32 then "Write-Output hello" else "echo hello"

let command_for_mixed_streams_nonzero () =
  if Sys.win32 then
    "Write-Output out; [Console]::Error.WriteLine('err'); exit 7"
  else "echo out; echo err 1>&2; exit 7"

let command_for_argument_echo value =
  if Sys.win32 then "Write-Output " ^ value else "printf '%s\\n' " ^ value

let run_exec command =
  Exec_command.run
    {working_directory= Sys.getcwd ()}
    (`Assoc [("command", `String command)])

let test_success_exit_code_zero () =
  let command = command_for_simple_output () in
  let result = run_exec command in
  let output =
    match result with
    | Ok out ->
        out
    | Error e ->
        Alcotest.fail ("exec_command should succeed, got error: " ^ e)
  in
  Alcotest.(check bool)
    "status code is zero" true
    (contains output "status code: 0") ;
  Alcotest.(check bool) "stdout is present" true (contains output "hello")

let test_nonzero_exit_and_combined_streams () =
  let command = command_for_mixed_streams_nonzero () in
  let result = run_exec command in
  let output =
    match result with
    | Ok out ->
        out
    | Error e ->
        Alcotest.fail ("exec_command should succeed, got error: " ^ e)
  in
  Alcotest.(check bool)
    "non-zero status reported" true
    (contains output "status code: 7") ;
  Alcotest.(check bool) "stdout is present" true (contains output "out") ;
  Alcotest.(check bool) "stderr is present" true (contains output "err")

let test_argument_list_passed () =
  let arg = "hello-token-value" in
  let command = command_for_argument_echo arg in
  let result = run_exec command in
  let output =
    match result with
    | Ok out ->
        out
    | Error e ->
        Alcotest.fail ("exec_command should succeed, got error: " ^ e)
  in
  Alcotest.(check bool) "argument value preserved" true (contains output arg)

let test_missing_program_validation_error () =
  let result =
    Exec_command.run
      {working_directory= Sys.getcwd ()}
      (`Assoc [("args", `List [`String "x"])])
  in
  Alcotest.(check string_result_testable)
    "missing required command is rejected"
    (Error "missing required argument: command") result

let test_wrong_args_type_validation_error () =
  let result =
    Exec_command.run
      {working_directory= Sys.getcwd ()}
      (`Assoc [("command", `List [`String "echo"])])
  in
  Alcotest.(check string_result_testable)
    "wrong command type is rejected"
    (Error "Cannot call tool 'exec_command': Expected string, got array") result

let tests =
  ( "exec_command"
  , [ Alcotest.test_case "success status zero" `Quick test_success_exit_code_zero
    ; Alcotest.test_case "non-zero + combined streams" `Quick
        test_nonzero_exit_and_combined_streams
    ; Alcotest.test_case "argument passing" `Quick test_argument_list_passed
    ; Alcotest.test_case "missing required argument" `Quick
        test_missing_program_validation_error
    ; Alcotest.test_case "wrong args type" `Quick
        test_wrong_args_type_validation_error ] )
