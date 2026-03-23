open Agentlib

let run_agent (type a) (module A : Agent.AGENT with type t = a)
    (agent_result : (a, Agent.agent_error) result) prompt =
  let res =
    Result.bind agent_result (fun agent ->
        A.send_request agent prompt |> Lwt_main.run )
  in
  match res with
  | Error error ->
      Printf.fprintf stderr "ERROR: %s\n" error.message ;
      exit 1
  | Ok response ->
      print_endline response.response

let usage () =
  Printf.eprintf "Agent-Run: LLM Agent Runner\n\n" ;
  Printf.eprintf "Usage: agent-run [options] <prompt>\n\n" ;
  Printf.eprintf "Options:\n" ;
  Printf.eprintf "  --vendor, -v  LLM vendor (openai, gemini, ollama)\n" ;
  Printf.eprintf "  --config, -c  Path to TOML config file\n\n" ;
  Printf.eprintf "Environment variables:\n" ;
  Printf.eprintf "  OPENAI_API_KEY - API key for OpenAI\n" ;
  Printf.eprintf "  GEMINI_API_KEY - API key for Gemini\n"

type vendor = OpenAi | Gemini | Ollama

(** application parameters defined when starting the program *)
type params = {vendor_name: string; config_path: string option}

(** Structural representation of all CLI parameters *)
type cli_params = {prompt: string option; params: params}

(** Parses app parameters from argv *)
let parse_params () =
  let default_params =
    {prompt= None; params= {vendor_name= "openai"; config_path= None}}
  in
  let rec loop argv params =
    match argv with
    | ("--vendor" | "-v") :: vendor :: rest ->
        loop rest {params with params= {params.params with vendor_name= vendor}}
    | ("--config" | "-c") :: path :: rest ->
        loop rest
          {params with params= {params.params with config_path= Some path}}
    | prompt :: rest ->
        loop rest {params with prompt= Some prompt}
    | [] ->
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

module OpenAiAgent = Openai_agent.Make (Agent.RealHttpClient)
module OllamaAgent = Ollama_agent.Make (Agent.RealHttpClient)
module GeminiAgent = Gemini_agent.Make (Agent.RealHttpClient)

let run vendor app_config prompt =
  match vendor with
  | OpenAi ->
      run_agent (module OpenAiAgent) (OpenAiAgent.create ()) prompt
  | Gemini ->
      run_agent (module GeminiAgent) (GeminiAgent.create ()) prompt
  | Ollama ->
      run_agent
        (module OllamaAgent)
        (Ok (OllamaAgent.create_with_options app_config.Config.ollama.url))
        prompt

let run_with_params params prompt =
  let config = Config.load params.config_path in
  match parse_vendor params.vendor_name with
  | Some vendor ->
      run vendor config prompt
  | None ->
      Printf.eprintf "ERROR: unknown vendor \"%s\"\n" params.vendor_name ;
      exit 1

let () =
  let all_params = parse_params () in
  match all_params with
  | {prompt= None; _} ->
      usage () ; exit 1
  | {prompt= Some prompt; params} ->
      run_with_params params prompt
