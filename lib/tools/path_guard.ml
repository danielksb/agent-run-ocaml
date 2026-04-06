let normalize_for_compare path =
  if Sys.win32 then
    path
    |> String.map (fun ch -> if ch = '/' then '\\' else ch)
    |> String.lowercase_ascii
  else path

let is_path_within_root ~root ~path =
  let root_norm = normalize_for_compare root in
  let path_norm = normalize_for_compare path in
  let root_with_sep = root_norm ^ Filename.dir_sep in
  String.equal path_norm root_norm
  || String.starts_with ~prefix:root_with_sep path_norm

let make_abs_path ~cwd path =
  if Filename.is_relative path then Filename.concat cwd path else path

let cwd_root () = Unix.realpath (Sys.getcwd ())

type mode = Must_exist | May_create

let access_denied_error path cwd =
  Printf.sprintf
    "Access denied: path '%s' is outside the current working directory (%s)"
    path cwd

let realpath_result path =
  try Ok (Unix.realpath path) with
  | Unix.Unix_error (err, _, _) ->
      Error
        (Printf.sprintf "Cannot resolve path '%s': %s" path
           (Unix.error_message err) )
  | Sys_error msg ->
      Error (Printf.sprintf "Cannot resolve path '%s': %s" path msg)

let guard_path path =
  let cwd = cwd_root () in
  let abs_path = make_abs_path ~cwd path in
  let resolved_target =
    if Sys.file_exists abs_path then realpath_result abs_path
    else
      Result.map
        (fun parent_resolved ->
          Filename.concat parent_resolved (Filename.basename abs_path) )
        (realpath_result (Filename.dirname abs_path))
  in
  Result.bind resolved_target (fun resolved_target ->
      if is_path_within_root ~root:cwd ~path:resolved_target then Ok abs_path
      else Error (access_denied_error path cwd) )
