open Agentlib
open Config

let usage () =
  Printf.eprintf "Agent-Run: LLM Agent Runner\n\n" ;
  Printf.eprintf "Usage: agent-run [options] <prompt>\n\n" ;
  Printf.eprintf "Options:\n" ;
  Printf.eprintf "  --help, -h   Display usage info\n" ;
  Printf.eprintf "  --debug, -d   Enable debug logs to stderr\n" ;
  Printf.eprintf "  --verbose, -V Enable verbose logs to stdout\n" ;
  Printf.eprintf "  --prompt, -p  Prompt for LLM request\n" ;
  Printf.eprintf "  --vendor, -v  LLM vendor (openai, gemini, ollama)\n" ;
  Printf.eprintf "  --model, -m   Model override for selected vendor\n" ;
  Printf.eprintf "  --base-url, -b Base URL override for selected vendor\n" ;
  Printf.eprintf "  --config, -c  Path to TOML config file\n" ;
  Printf.eprintf "  --working-directory, -w Working directory for file tools\n" ;
  Printf.eprintf "  --skill, -s   Path to SKILL.md file (can be repeated)\n\n" ;
  Printf.eprintf "Environment variables:\n" ;
  Printf.eprintf "  OPENAI_API_KEY - API key for OpenAI\n" ;
  Printf.eprintf "  GEMINI_API_KEY - API key for Gemini\n"

type vendor = OpenAi | Gemini | Ollama

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
  loop (Array.to_list Sys.argv |> List.drop 1) default_params

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

module ProdTools = struct
  let registry = Tool_registry.default_registry
end

module DefaultHttpClient = Http_client.Default
module OpenAiAgent =
  Agent.Make (Openai_agent.Vendor) (DefaultHttpClient) (ProdTools)
module OllamaAgent =
  Agent.Make (Ollama_agent.Vendor) (DefaultHttpClient) (ProdTools)
module GeminiAgent =
  Agent.Make (Gemini_agent.Vendor) (DefaultHttpClient) (ProdTools)

let handle_result = function
  | Error (error : Agent.agent_error) ->
      Printf.fprintf stderr "ERROR: %s\n" error.message ;
      exit 1
  | Ok (response : Agent.agent_response) ->
      print_endline response.response

let run_agent (type a) (module A : Agent.AGENT with type t = a)
    (agent_result : (a, Agent.agent_error) result) prompt =
  Result.bind agent_result (fun agent ->
      A.send_request agent prompt |> Lwt_main.run )
  |> handle_result

let run vendor app_config prompt params working_directory =
  let tool_context = Tool_registry.{working_directory} in
  match vendor with
  | OpenAi ->
      let model_name =
        Option.value params.model_name ~default:app_config.openai.model
      in
      let base_url =
        Option.value params.base_url ~default:app_config.openai.base_url
      in
      let agent_result =
        match Sys.getenv_opt "OPENAI_API_KEY" with
        | Some api_key ->
            Ok
              (OpenAiAgent.create
                 {model_name; api_key; base_url; tool_context} )
        | None ->
            Error Agent.{message= "OPENAI_API_KEY environment variable not set"}
      in
      run_agent (module OpenAiAgent) agent_result prompt
  | Gemini ->
      let model_name =
        Option.value params.model_name ~default:app_config.gemini.model
      in
      let base_url =
        Option.value params.base_url ~default:app_config.gemini.base_url
      in
      let agent_result =
        match Sys.getenv_opt "GEMINI_API_KEY" with
        | Some api_key ->
            Ok
              (GeminiAgent.create
                 {model_name; api_key; base_url; tool_context} )
        | None ->
            Error Agent.{message= "GEMINI_API_KEY environment variable not set"}
      in
      run_agent (module GeminiAgent) agent_result prompt
  | Ollama ->
      let model_name =
        Option.value params.model_name ~default:app_config.ollama.model
      in
      let base_url =
        Option.value params.base_url ~default:app_config.ollama.base_url
      in
      let agent_result =
        Ok
          (OllamaAgent.create
             {model_name; api_key= ""; base_url; tool_context} )
      in
      run_agent (module OllamaAgent) agent_result prompt

let resolve_skill_path skill_path =
  if Filename.is_relative skill_path then
    Filename.concat (Sys.getcwd ()) skill_path
  else skill_path

let load_skill_registry skill_paths =
  List.fold_left
    (fun registry skill_path ->
      let absolute_path = resolve_skill_path skill_path in
      match Skill.load_from_file absolute_path with
      | Ok _ ->
          Skill_registry.register_skill registry absolute_path
      | Error msg ->
          Printf.eprintf "ERROR: %s\n" msg ;
          exit 1 )
    (Skill_registry.empty ()) skill_paths

let run_with_params params prompt =
  if params.debug then Logging.set_level Logging.Debug
  else if params.verbose then Logging.set_level Logging.Verbose
  else Logging.set_level Logging.Normal ;
  let config = Config.load params.config_path in
  let effective_working_directory =
    match params.working_directory with
    | Some _ as dir ->
        dir
    | None ->
        config.working_directory
  in
  let working_directory =
    Option.value effective_working_directory ~default:(Sys.getcwd ())
  in
  let prompt =
    params.skill_paths |> List.rev |> load_skill_registry
    |> Skill_registry.augment_prompt ~original_prompt:prompt
  in
  match parse_vendor params.vendor_name with
  | Some vendor ->
      run vendor config prompt params working_directory
  | None ->
      Printf.eprintf "ERROR: unknown vendor \"%s\"\n" params.vendor_name ;
      exit 1

let () =
  let params = parse_params () in
  match params with
  | {help= true} ->
      usage ()
  | {prompt= None} ->
      let prompt = In_channel.input_all stdin in
      run_with_params params prompt
  | {prompt= Some prompt} ->
      (* if the prompt is a file path then the content of the file will be the
         actual prompt *)
      if Sys.file_exists prompt && Sys.is_regular_file prompt then
        let actual_prompt = open_in prompt |> In_channel.input_all in
        run_with_params params actual_prompt
      else run_with_params params prompt
