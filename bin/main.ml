open Agent_run

module RunRequest (A : Agent.AGENT) = struct
  let run prompt =
    let res =
      Result.bind (A.create ()) (fun agent ->
          A.send_request agent prompt |> Lwt_main.run )
    in
    match res with
    | Error error ->
        Printf.fprintf stderr "ERROR: %s\n" error.message ;
        exit 1
    | Ok response ->
        print_endline response.response
end

let usage () =
  Printf.eprintf "Agent-Run: LLM Agent Runner\n\n" ;
  Printf.eprintf "Usage: agent-run <prompt>\n\n" ;
  Printf.eprintf "Environment variables:\n" ;
  Printf.eprintf "  OPENAI_API_KEY - API key for OpenAI:\n" ;
  Printf.eprintf "  GEMINI_API_KEY - API key for Gemini:\n"

type config = {prompt: string option; vendor: string}

let create_config () =
  let default_config = {prompt= None; vendor= "openai"} in
  let rec loop argv config =
    match argv with
    | ("--vendor" | "-v") :: vendor :: rest ->
        loop rest {config with vendor}
    | prompt :: rest ->
        loop rest {config with prompt= Some prompt}
    | [] ->
        config
  in
  loop (Array.to_list Sys.argv |> List.drop 1) default_config

let () =
  let config = create_config () in
  match config.prompt with
  | Some prompt ->
      let module Run = RunRequest (Openai_agent.OpenAiAgent) in
      Run.run prompt
  | None ->
      usage () ; exit 1
