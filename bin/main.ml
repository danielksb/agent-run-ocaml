open Agent_run

let () =
  let prompt = "Was ist die Hauptstadt von Deutschland?" in
  let api_key = Sys.getenv "OPENAI_API_KEY" in
  let req = Openai_agent.send_request prompt api_key in
  let res = Lwt_main.run req in
  match res with
  | Error error ->
      Printf.fprintf stderr "ERROR: %s\n" error.message
  | Ok {response; _} ->
      print_endline response
