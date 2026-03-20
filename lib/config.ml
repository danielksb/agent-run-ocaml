type ollama = {url: string}

type t = {ollama: ollama}

let default = {ollama= {url= "http://localhost:11434"}}

let home_dir () =
  match Sys.getenv_opt "HOME" with
  | Some h ->
      Some h
  | None ->
      Sys.getenv_opt "USERPROFILE"

let default_config_path () =
  Option.map (fun h -> Filename.concat h ".agent-run.toml") (home_dir ())

let ollama_url_lens =
  Toml.Lenses.(field "ollama" |-- key "url" |-- string)

let of_toml (table : Toml.Types.table) =
  let ollama_url =
    match Toml.Lenses.get table ollama_url_lens with
    | Some u ->
        u
    | None ->
        default.ollama.url
  in
  {ollama= {url= ollama_url}}

let from_file path =
  match Toml.Parser.from_filename path with
  | `Ok table ->
      of_toml table
  | `Error (msg, loc) ->
      Printf.ksprintf failwith "%s:%d:%d: %s" path loc.line loc.column msg

let load config_path =
  match config_path with
  | Some path ->
      from_file path
  | None -> (
    match default_config_path () with
    | Some path when Sys.file_exists path ->
        from_file path
    | _ ->
        default )
