open Agentlib

module CliPlatform = Cli.Make (struct
  include Sys

  let exit_with_error () = exit 1

  let stdin_read_all () = In_channel.input_all stdin

  let file_read_all file = open_in file |> In_channel.input_all
end)

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

let run_agent (type a) (module A : Agent.AGENT with type t = a) agent_config
    prompt =
  let agent = A.create agent_config in
  let result = A.send_request agent prompt |> Lwt_main.run in
  match result with
  | Error (error : Agent.agent_error) ->
      Printf.fprintf stderr "ERROR: %s\n" error.message ;
      exit 1
  | Ok (response : Agent.agent_response) ->
      print_endline response.response

let () =
  match CliPlatform.create_agent_config () with
  | Error msg ->
      Printf.eprintf "%s\n" (Cli.cli_msg_to_string msg) ;
      exit 1
  | Ok {agent_config; prompt; vendor} -> (
    match vendor with
    | Cli.OpenAi ->
        run_agent (module OpenAiAgent) agent_config prompt
    | Cli.Gemini ->
        run_agent (module GeminiAgent) agent_config prompt
    | Cli.Ollama ->
        run_agent (module OllamaAgent) agent_config prompt )
