open Agentlib

type t =
  { argv: string array
  ; cwd: string
  ; stdin: string
  ; env: (string, string) Hashtbl.t
  ; files: (string, string) Hashtbl.t
  ; regular_files: (string, unit) Hashtbl.t }

let create ?(argv = [|"agent-run"|]) ?(cwd = "C:\\mock-cwd") ?(stdin = "")
    ?(env = []) ?(files = []) ?regular_files () =
  let env_tbl = Hashtbl.create 16 in
  List.iter (fun (k, v) -> Hashtbl.replace env_tbl k v) env ;
  let files_tbl = Hashtbl.create 16 in
  List.iter
    (fun (path, content) -> Hashtbl.replace files_tbl path content)
    files ;
  let regular_tbl = Hashtbl.create 16 in
  let regular =
    match regular_files with
    | Some entries ->
        entries
    | None ->
        List.map fst files
  in
  List.iter (fun path -> Hashtbl.replace regular_tbl path ()) regular ;
  {argv; cwd; stdin; env= env_tbl; files= files_tbl; regular_files= regular_tbl}

let to_platform (mock : t) : (module Cli.PLATFORM) =
  let module Platform = struct
    let argv = mock.argv

    let getenv_opt key = Hashtbl.find_opt mock.env key

    let getcwd () = mock.cwd

    let file_exists path =
      Hashtbl.mem mock.files path || Hashtbl.mem mock.regular_files path

    let is_regular_file path = Hashtbl.mem mock.regular_files path

    let stdin_read_all () = mock.stdin

    let file_read_all path =
      match Hashtbl.find_opt mock.files path with
      | Some content ->
          content
      | None ->
          failwith ("MockPlatform.file_read_all: unknown path " ^ path)
  end in
  (module Platform : Cli.PLATFORM)
