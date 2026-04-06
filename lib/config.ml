type vendor = {model: string; base_url: string}

type t = {openai: vendor; gemini: vendor; ollama: vendor}

let default =
  { openai= {model= "gpt-4o-mini"; base_url= "https://api.openai.com"}
  ; gemini=
      { model= "gemini-flash-latest"
      ; base_url= "https://generativelanguage.googleapis.com" }
  ; ollama= {model= "gemma4:e2b"; base_url= "http://localhost:11434"} }

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

let ollama_model_lens = Toml.Lenses.(field "ollama" |-- key "model" |-- string)

let openai_base_url_lens =
  Toml.Lenses.(field "openai" |-- key "base_url" |-- string)

let gemini_base_url_lens =
  Toml.Lenses.(field "gemini" |-- key "base_url" |-- string)

let ollama_base_url_lens =
  Toml.Lenses.(field "ollama" |-- key "base_url" |-- string)

let of_toml (table : Toml.Types.table) =
  let openai_model =
    Toml.Lenses.get table openai_model_lens
    |> Option.value ~default:default.openai.model
  in
  let gemini_model =
    Toml.Lenses.get table gemini_model_lens
    |> Option.value ~default:default.gemini.model
  in
  let ollama_model =
    Toml.Lenses.get table ollama_model_lens
    |> Option.value ~default:default.ollama.model
  in
  let openai_base_url =
    Toml.Lenses.get table openai_base_url_lens
    |> Option.value ~default:default.openai.base_url
  in
  let gemini_base_url =
    Toml.Lenses.get table gemini_base_url_lens
    |> Option.value ~default:default.gemini.base_url
  in
  let ollama_base_url =
    Toml.Lenses.get table ollama_base_url_lens
    |> Option.value ~default:default.ollama.base_url
  in
  { openai= {model= openai_model; base_url= openai_base_url}
  ; gemini= {model= gemini_model; base_url= gemini_base_url}
  ; ollama= {model= ollama_model; base_url= ollama_base_url} }

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
