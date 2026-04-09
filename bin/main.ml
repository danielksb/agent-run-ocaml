open Agentlib

module CliPlatform = Cli.Make (struct
  include Sys

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

let agent_vendor_module = function
  | Cli.OpenAi ->
      (module OpenAiAgent : Agent.AGENT)
  | Cli.Gemini ->
      (module GeminiAgent : Agent.AGENT)
  | Cli.Ollama ->
      (module OllamaAgent : Agent.AGENT)

let run_agent (module A : Agent.AGENT) agent_config prompt =
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
  | Ok {agent_config; prompt; vendor} ->
      run_agent (agent_vendor_module vendor) agent_config prompt
