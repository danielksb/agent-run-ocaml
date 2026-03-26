open Agentlib

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

let usage () =
  Printf.eprintf "Agent-Run: LLM Agent Runner\n\n" ;
  Printf.eprintf "Usage: agent-run [options] <prompt>\n\n" ;
  Printf.eprintf "Options:\n" ;
  Printf.eprintf "  --prompt, -p  Prompt for LLM request\n" ;
  Printf.eprintf "  --vendor, -v  LLM vendor (openai, gemini, ollama)\n" ;
  Printf.eprintf "  --model, -m   Model override for selected vendor\n" ;
  Printf.eprintf "  --config, -c  Path to TOML config file\n\n" ;
  Printf.eprintf "Environment variables:\n" ;
  Printf.eprintf "  OPENAI_API_KEY - API key for OpenAI\n" ;
  Printf.eprintf "  GEMINI_API_KEY - API key for Gemini\n"

type vendor = OpenAi | Gemini | Ollama

(** application parameters defined when starting the program *)
type params =
  { vendor_name: string
  ; config_path: string option
  ; model_name: string option }

(** Structural representation of all CLI parameters *)
type cli_params = {prompt: string option; params: params}

(** Parses app parameters from argv *)
let parse_params () =
  let default_params =
    { prompt= None
    ; params= {vendor_name= "openai"; config_path= None; model_name= None} }
  in
  let rec loop argv params =
    match argv with
    | ("--vendor" | "-v") :: vendor :: rest ->
        loop rest {params with params= {params.params with vendor_name= vendor}}
    | ("--config" | "-c") :: path :: rest ->
        loop rest
          {params with params= {params.params with config_path= Some path}}
    | ("--model" | "-m") :: model :: rest ->
        loop rest
          {params with params= {params.params with model_name= Some model}}
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

let run vendor app_config prompt model_name =
  match vendor with
  | OpenAi ->
      let agent_result =
        Result.map
          (fun agent ->
            match model_name with
            | Some model ->
                OpenAiAgent.with_model agent model
            | None ->
                agent )
          (OpenAiAgent.create ())
      in
      run_agent (module OpenAiAgent) agent_result prompt
  | Gemini ->
      let agent_result =
        Result.map
          (fun agent ->
            match model_name with
            | Some model ->
                GeminiAgent.with_model agent model
            | None ->
                agent )
          (GeminiAgent.create ())
      in
      run_agent (module GeminiAgent) agent_result prompt
  | Ollama ->
      let agent =
        OllamaAgent.create_with_options app_config.Config.ollama.url
        |> fun agent ->
        match model_name with
        | Some model ->
            OllamaAgent.with_model agent model
        | None ->
            agent
      in
      run_agent (module OllamaAgent) (Ok agent) prompt

let run_with_params params prompt =
  let config = Config.load params.config_path in
  match parse_vendor params.vendor_name with
  | Some vendor ->
      run vendor config prompt params.model_name
  | None ->
      Printf.eprintf "ERROR: unknown vendor \"%s\"\n" params.vendor_name ;
      exit 1

let () =
  let all_params = parse_params () in
  match all_params with
  | {prompt= None; _} ->
      Printf.eprintf "ERROR: no prompt was given\n" ;
      usage () ;
      exit 1
  | {prompt= Some prompt; params} ->
      run_with_params params prompt
