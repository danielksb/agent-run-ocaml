module type PLATFORM = sig
  val argv : string array

  val getenv_opt : string -> string option

  val getcwd : unit -> string

  val file_exists : string -> bool

  val is_regular_file : string -> bool

  val stdin_read_all : unit -> string

  val file_read_all : string -> string
end

type vendor = OpenAi | Gemini | Ollama

type cli_msg =
  | Usage
  | NoPrompt
  | UnknownVendor of string
  | NoApiKey of string
  | LoadSkillFailed of string

type runtime_parameters =
  {agent_config: Agent.config; vendor: vendor; prompt: string}

module type S = sig
  val create_agent_config : unit -> (runtime_parameters, cli_msg) result
end

let usage =
  {|
    Agent-Run: LLM Agent Runner

    Usage: agent-run [options] --prompt <prompt>

    Options:
      --help, -h   Display usage info
      --debug, -d   Enable debug logs to stderr
      --verbose, -V Enable verbose logs to stdout
      --prompt, -p  Prompt for LLM request, uses stdin when "-"
      --vendor, -v  LLM vendor (openai, gemini, ollama)
      --model, -m   Model override for selected vendor
      --base-url, -b Base URL override for selected vendor
      --config, -c  Path to TOML config file
      --working-directory, -w Working directory for file tools
      --skill, -s   Path to SKILL.md file (can be repeated)

    Environment variables:
      OPENAI_API_KEY - API key for OpenAI
      GEMINI_API_KEY - API key for Gemini
|}

let cli_msg_to_string = function
  | Usage ->
      usage
  | UnknownVendor vendor ->
      Printf.sprintf "ERROR: unknown vendor \"%s\"\n" vendor
  | NoPrompt ->
      "ERROR: no prompt was defined.\n\n"
      ^ "Use the command line argument \"--prompt\"/\"-p\" to set a prompt. "
      ^ "Pass \"--prompt -\" to read a prompt from stdin."
  | LoadSkillFailed msg ->
      Printf.sprintf "ERROR: %s\n" msg
  | NoApiKey key ->
      key ^ " environment variable not set"

module Make (Platform : PLATFORM) = struct
  open Config

  (** application parameters defined when starting the program *)
  type params =
    { vendor_name: string
    ; config_path: string option
    ; skill_paths: string list
    ; model_name: string option
    ; base_url: string option
    ; working_directory: string option
    ; debug: bool
    ; verbose: bool
    ; prompt: string option
    ; help: bool }

  (** Parses app parameters from argv *)
  let parse_params () =
    let default_params =
      { vendor_name= "openai"
      ; config_path= None
      ; skill_paths= []
      ; model_name= None
      ; base_url= None
      ; working_directory= None
      ; debug= false
      ; verbose= false
      ; prompt= None
      ; help= false }
    in
    let rec loop argv params =
      match argv with
      | ("--debug" | "-d") :: rest ->
          loop rest {params with debug= true}
      | ("--verbose" | "-V") :: rest ->
          loop rest {params with verbose= true}
      | ("--vendor" | "-v") :: vendor :: rest ->
          loop rest {params with vendor_name= vendor}
      | ("--config" | "-c") :: path :: rest ->
          loop rest {params with config_path= Some path}
      | ("--skill" | "-s") :: path :: rest ->
          loop rest {params with skill_paths= path :: params.skill_paths}
      | ("--model" | "-m") :: model :: rest ->
          loop rest {params with model_name= Some model}
      | ("--base-url" | "-b") :: base_url :: rest ->
          loop rest {params with base_url= Some base_url}
      | ("--working-directory" | "-w") :: working_directory :: rest ->
          loop rest {params with working_directory= Some working_directory}
      | ("--prompt" | "-p") :: prompt :: rest ->
          loop rest {params with prompt= Some prompt}
      | ("--help" | "-h") :: rest ->
          loop rest {params with help= true}
      | rest ->
          params
    in
    loop (Array.to_list Platform.argv |> List.drop 1) default_params

  let parse_vendor str =
    match str with
    | "openai" ->
        Some OpenAi
    | "gemini" ->
        Some Gemini
    | "ollama" ->
        Some Ollama
    | _ ->
        None

  let agent_app_config vendor app_config =
    match vendor with
    | OpenAi ->
        app_config.openai
    | Gemini ->
        app_config.gemini
    | Ollama ->
        app_config.ollama

  let retrieve_api_key vendor =
    let key_name =
      match vendor with
      | OpenAi ->
          "OPENAI_API_KEY"
      | Gemini ->
          "GEMINI_API_KEY"
      | Ollama ->
          "OLLAMA_API_KEY"
    in
    match Platform.getenv_opt key_name with
    | None ->
        if vendor = Ollama then Ok "" else Error (NoApiKey key_name)
    | Some api_key ->
        Ok api_key

  let resolve_skill_path skill_path =
    if Filename.is_relative skill_path then
      Filename.concat (Platform.getcwd ()) skill_path
    else skill_path

  let load_skill registry skill_path =
    let absolute_path = resolve_skill_path skill_path in
    match Skill.load_from_file absolute_path with
    | Ok _ ->
        Result.ok @@ Skill_registry.register_skill registry absolute_path
    | Error msg ->
        Result.error @@ LoadSkillFailed msg

  let load_skill_registry skill_paths =
    let empty_registry = Result.ok @@ Skill_registry.empty () in
    List.fold_left
      (fun registry skill_path ->
        Result.bind registry (fun reg -> load_skill reg skill_path) )
      empty_registry skill_paths

  let build_runtime_params params prompt =
    let ( let* ) = Result.bind in
    let ( <|> ) = fun a b -> if Option.is_some a then a else b in
    let config = Config.load params.config_path in
    let working_directory =
      params.working_directory <|> config.working_directory
      |> Option.value ~default:(Platform.getcwd ())
    in
    let* prompt =
      params.skill_paths |> List.rev |> load_skill_registry
      |> Result.map (fun reg ->
          Skill_registry.augment_prompt reg ~original_prompt:prompt )
    in
    let* vendor =
      parse_vendor params.vendor_name
      |> Option.to_result ~none:(UnknownVendor params.vendor_name)
    in
    let tool_context = Tool.{working_directory} in
    let agent_app_config = agent_app_config vendor config in
    let model_name =
      Option.value params.model_name ~default:agent_app_config.model
    in
    let base_url =
      Option.value params.base_url ~default:agent_app_config.base_url
    in
    let* api_key = retrieve_api_key vendor in
    let agent_config = Agent.{model_name; api_key; base_url; tool_context} in
    Ok {agent_config; vendor; prompt}

  let set_log_level params =
    if params.debug then Logging.set_level Logging.Debug
    else if params.verbose then Logging.set_level Logging.Verbose
    else Logging.set_level Logging.Normal

  let create_agent_config () =
    let params = parse_params () in
    set_log_level params ;
    match params with
    | {help= true} ->
        Error Usage
    | {prompt= None} ->
        Error NoPrompt
    | {prompt= Some "-"} ->
        let prompt = Platform.stdin_read_all () in
        build_runtime_params params prompt
    | {prompt= Some prompt} ->
        (* if the prompt is a file path then the content of the file will be the
           actual prompt *)
        if Platform.file_exists prompt && Platform.is_regular_file prompt then
          let actual_prompt = Platform.file_read_all prompt in
          build_runtime_params params actual_prompt
        else build_runtime_params params prompt
end
