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
  Printf.eprintf "  OPENAI_API_KEY - API key for OpenAI:\n"

let () =
  match Array.to_list Sys.argv with
  | [_; prompt] ->
      let module Run = RunRequest (Openai_agent.OpenAiAgent) in
      Run.run prompt
  | _ ->
      usage () ; exit 1
