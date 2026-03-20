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

let usage () = Printf.fprintf stderr "Usage:\n agent-run PROMPT\n"

let () =
  let prompt = if Array.length Sys.argv > 1 then Some Sys.argv.(1) else None in
  match prompt with
  | None ->
      Printf.fprintf stderr "ERROR: No prompt received\n" ;
      usage () ;
      exit 1
  | Some prompt ->
      let module Run = RunRequest (Openai_agent.OpenAiAgent) in
      Run.run prompt
