open Agent_run

module RunRequest (A : Agent.AGENT) = struct
  let run prompt =
    let agent = A.create () in
    let res = A.send_request agent prompt |> Lwt_main.run in
    match res with
    | Error error ->
        Printf.fprintf stderr "ERROR: %s\n" error.message
    | Ok {response; _} ->
        print_endline response
end

let () =
  let prompt = "Was ist die Hauptstadt von Deutschland?" in
  let module Run = RunRequest (Openai_agent.OpenAiAgent) in
  Run.run prompt
