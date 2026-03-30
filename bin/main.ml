open Agentlib

let usage () =
  Printf.eprintf "Agent-Run: LLM Agent Runner\n\n" ;
  Printf.eprintf "Usage: agent-run [options] <prompt>\n\n" ;
  Printf.eprintf "Options:\n" ;
  Printf.eprintf "  --debug, -d   Enable debug logs to stderr\n" ;
  Printf.eprintf "  --verbose, -V Enable verbose logs to stdout\n" ;
  Printf.eprintf "  --prompt, -p  Prompt for LLM request\n" ;
  Printf.eprintf "  --vendor, -v  LLM vendor (openai, gemini, ollama)\n" ;
  Printf.eprintf "  --model, -m   Model override for selected vendor\n" ;
  Printf.eprintf "  --config, -c  Path to TOML config file\n" ;
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
  ; debug: bool
  ; verbose: bool
  ; prompt: string option }

(** Parses app parameters from argv *)
let parse_params () =
  let default_params =
    { vendor_name= "openai"
    ; config_path= None
    ; skill_paths= []
    ; model_name= None
    ; debug= false
    ; verbose= false
    ; prompt= None }
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
    | ("--prompt" | "-p") :: prompt :: rest ->
        loop rest {params with prompt= Some prompt}
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
  let registry = Tool_registry.default_registry ()
end

module OpenAiAgent = Openai_agent.Make (Agent.RealHttpClient) (ProdTools)
module OllamaAgent = Ollama_agent.Make (Agent.RealHttpClient) (ProdTools)
module GeminiAgent = Gemini_agent.Make (Agent.RealHttpClient) (ProdTools)

let handle_result = function
  | Error (error : Agent.agent_error) ->
      Printf.fprintf stderr "ERROR: %s\n" error.message ;
      exit 1
  | Ok (response : Agent.agent_response) ->
      print_endline response.response

let run_agent (type a) (module A : Agent.AGENT with type t = a)
    (agent_result : (a, Agent.agent_error) result) prompt =
  Result.bind agent_result (fun agent ->
      A.agent_loop agent prompt |> Lwt_main.run )
  |> handle_result

let run vendor app_config prompt params =
  match vendor with
  | OpenAi ->
      let model_name = Option.value params.model_name ~default:"gpt-4o-mini" in
      let agent_result =
        match Sys.getenv_opt "OPENAI_API_KEY" with
        | Some api_key ->
            Ok
              (OpenAiAgent.create
                 {model_name; api_key; base_url= "https://api.openai.com"} )
        | None ->
            Error Agent.{message= "OPENAI_API_KEY environment variable not set"}
      in
      run_agent (module OpenAiAgent) agent_result prompt
  | Gemini ->
      let model_name =
        Option.value params.model_name ~default:"gemini-flash-latest"
      in
      let agent_result =
        match Sys.getenv_opt "GEMINI_API_KEY" with
        | Some api_key ->
            Ok
              (GeminiAgent.create
                 { model_name
                 ; api_key
                 ; base_url= "https://generativelanguage.googleapis.com" } )
        | None ->
            Error Agent.{message= "GEMINI_API_KEY environment variable not set"}
      in
      run_agent (module GeminiAgent) agent_result prompt
  | Ollama ->
      let model_name =
        Option.value params.model_name ~default:"functiongemma"
      in
      let agent_result =
        Ok
          (OllamaAgent.create
             {model_name; api_key= ""; base_url= "http://localhost:11434"} )
      in
      run_agent (module OllamaAgent) agent_result prompt

let run_with_params params prompt =
  if params.debug then Logging.set_level Logging.Debug
  else if params.verbose then Logging.set_level Logging.Verbose
  else Logging.set_level Logging.Normal ;
  let config = Config.load params.config_path in
  let prompt =
    match List.rev params.skill_paths with
    | [] ->
        prompt
    | skill_paths ->
        let parsed_skills =
          List.map
            (fun skill_path ->
              let absolute_path =
                if Filename.is_relative skill_path then
                  Filename.concat (Sys.getcwd ()) skill_path
                else skill_path
              in
              match Skill.from_file absolute_path with
              | Ok skill ->
                  skill
              | Error msg ->
                  Printf.eprintf "ERROR: %s\n" msg ;
                  exit 1 )
            skill_paths
        in
        Skill.augment_prompt_many ~original_prompt:prompt ~skills:parsed_skills
  in
  match parse_vendor params.vendor_name with
  | Some vendor ->
      run vendor config prompt params
  | None ->
      Printf.eprintf "ERROR: unknown vendor \"%s\"\n" params.vendor_name ;
      exit 1

let () =
  let params = parse_params () in
  match params.prompt with
  | None ->
      let prompt = In_channel.input_all stdin in
      run_with_params params prompt
  | Some prompt ->
      (* if the prompt is a file path then the content of the file will be the
         actual prompt *)
      if Sys.file_exists prompt && Sys.is_regular_file prompt then
        let actual_prompt = open_in prompt |> In_channel.input_all in
        run_with_params params actual_prompt
      else run_with_params params prompt
