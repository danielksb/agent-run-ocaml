type vendor = {model: string option}

type ollama =
  {url: string; model: string option}

type t =
  {openai: vendor; gemini: vendor; ollama: ollama}

let default =
  { openai= {model= None}
  ; gemini= {model= None}
  ; ollama= {url= "http://localhost:11434"; model= None} }

let home_dir () =
  match Sys.getenv_opt "HOME" with
  | Some h ->
      Some h
  | None ->
      Sys.getenv_opt "USERPROFILE"

let default_config_path () =
  Option.map (fun h -> Filename.concat h ".agent-run.toml") (home_dir ())

let openai_model_lens = Toml.Lenses.(field "openai" |-- key "model" |-- string)

let gemini_model_lens = Toml.Lenses.(field "gemini" |-- key "model" |-- string)

let ollama_url_lens = Toml.Lenses.(field "ollama" |-- key "url" |-- string)

let ollama_model_lens = Toml.Lenses.(field "ollama" |-- key "model" |-- string)

let of_toml (table : Toml.Types.table) =
  let openai_model = Toml.Lenses.get table openai_model_lens in
  let gemini_model = Toml.Lenses.get table gemini_model_lens in
  let ollama_url =
    match Toml.Lenses.get table ollama_url_lens with
    | Some u ->
        u
    | None ->
        default.ollama.url
  in
  let ollama_model = Toml.Lenses.get table ollama_model_lens in
  { openai= {model= openai_model}
  ; gemini= {model= gemini_model}
  ; ollama= {url= ollama_url; model= ollama_model} }

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
