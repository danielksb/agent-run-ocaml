open Agent_run

let run_agent
    (type a)
    (module A : Agent.AGENT with type t = a)
    (agent_result : (a, Agent.agent_error) result)
    prompt =
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

type cli_config = {vendor_name: string; config_path: string option}

type parameters = {prompt: string option; config: cli_config}

let create_params () =
  let default_params =
    {prompt= None; config= {vendor_name= "openai"; config_path= None}}
  in
  let rec loop argv params =
    match argv with
    | ("--vendor" | "-v") :: vendor :: rest ->
        loop rest
          {params with config= {params.config with vendor_name= vendor}}
    | ("--config" | "-c") :: path :: rest ->
        loop rest
          {params with config= {params.config with config_path= Some path}}
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

let run vendor app_config prompt =
  match vendor with
  | OpenAi ->
      run_agent (module Openai_agent.OpenAiAgent)
        (Openai_agent.OpenAiAgent.create ())
        prompt
  | Gemini ->
      run_agent (module Gemini_agent.GeminiAgent)
        (Gemini_agent.GeminiAgent.create ())
        prompt
  | Ollama ->
      run_agent (module Ollama_agent.OllamaAgent)
        (Ok
           (Ollama_agent.OllamaAgent.create_with_options
              app_config.Config.ollama.url ) )
        prompt

let run_with_vendor cli_config prompt =
  let app_config = Config.load cli_config.config_path in
  match parse_vendor cli_config.vendor_name with
  | Some vendor ->
      run vendor app_config prompt
  | None ->
      Printf.eprintf "ERROR: unknown vendor \"%s\"\n" cli_config.vendor_name ;
      exit 1

let () =
  let params = create_params () in
  match params with
  | {prompt= None; _} ->
      usage () ; exit 1
  | {prompt= Some prompt; config} ->
      run_with_vendor config prompt
