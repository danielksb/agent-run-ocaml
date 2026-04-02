let definition : Tool.t =
  { type_= "function"
  ; name= "exec_command"
  ; description=
      "Execute a shell command and return status code plus combined \
       stdout/stderr output."
  ; parameters=
      { type_= "object"
      ; properties=
          Tool.StringMap.empty
          |> Tool.StringMap.add "command"
               Tool.
                 { type_= "string"
                 ; description= Some "Shell command string to execute."
                 ; enum= None
                 ; items= None }
      ; required= ["command"] }
  ; strict= true }

let prefixed_error message =
  Error ("Cannot call tool 'exec_command': " ^ message)

let read_all_fd fd =
  let buf = Buffer.create 4096 in
  let chunk = Bytes.create 4096 in
  let rec loop () =
    match Unix.read fd chunk 0 (Bytes.length chunk) with
    | 0 ->
        ()
    | n ->
        Buffer.add_subbytes buf chunk 0 n ;
        loop ()
  in
  loop () ; Buffer.contents buf

let status_to_code = function
  | Unix.WEXITED code ->
      code
  | Unix.WSIGNALED signal ->
      128 + signal
  | Unix.WSTOPPED signal ->
      128 + signal

let run_child ~program ~argv ~envp ~write_fd =
  Unix.dup2 write_fd Unix.stdout ;
  Unix.dup2 write_fd Unix.stderr ;
  Unix.close write_fd ;
  try Unix.execvpe program argv envp
  with Unix.Unix_error (err, fn, arg) ->
    prerr_endline
      (Printf.sprintf "execvpe failed: %s (%s %s)" (Unix.error_message err) fn
         arg ) ;
    exit 127

let execute_windows ~program ~argv ~envp =
  let read_fd, write_fd = Unix.pipe () in
  try
    let pid =
      Unix.create_process_env program argv envp Unix.stdin write_fd write_fd
    in
    Unix.close write_fd ;
    let output = read_all_fd read_fd in
    Unix.close read_fd ;
    let _, status = Unix.waitpid [] pid in
    let status_code = status_to_code status in
    Ok (Printf.sprintf "status code: %d\n%s" status_code output)
  with exn -> Unix.close read_fd ; Unix.close write_fd ; raise exn

let execute_posix ~program ~argv ~envp =
  let read_fd, write_fd = Unix.pipe () in
  match Unix.fork () with
  | 0 ->
      Unix.close read_fd ;
      run_child ~program ~argv ~envp ~write_fd
  | pid ->
      Unix.close write_fd ;
      let output = read_all_fd read_fd in
      Unix.close read_fd ;
      let _, status = Unix.waitpid [] pid in
      let status_code = status_to_code status in
      Ok (Printf.sprintf "status code: %d\n%s" status_code output)

let execute command =
  let program, argv, envp =
    if Sys.win32 then
      ( "powershell.exe"
      , [| "powershell.exe"
         ; "-NoProfile"
         ; "-Command"
         ; "Invoke-Expression $env:AGENT_RUN_EXEC_COMMAND" |]
      , Array.append
          (Unix.environment ())
          [| "AGENT_RUN_EXEC_COMMAND=" ^ command |] )
    else ("sh", [|"sh"; "-c"; command|], Unix.environment ())
  in
  try
    if Sys.win32 then execute_windows ~program ~argv ~envp
    else execute_posix ~program ~argv ~envp
  with Unix.Unix_error (err, fn, arg) ->
    prefixed_error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

let parse_command args =
  try Ok (Yojson.Safe.Util.member "command" args |> Yojson.Safe.Util.to_string)
  with Yojson.Safe.Util.Type_error (msg, _) -> prefixed_error msg

let run (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok args ->
      Result.bind (parse_command args) execute
