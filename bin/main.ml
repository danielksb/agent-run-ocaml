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

type vendor = OpenAi | Gemini

type config = {vendor_name: string}

type parameters = {prompt: string option; config: config}

let create_params () =
  let default_params = {prompt= None; config= {vendor_name= "openai"}} in
  let rec loop argv params =
    match argv with
    | ("--vendor" | "-v") :: vendor :: rest ->
        loop rest {params with config= {vendor_name= vendor}}
    | prompt :: rest ->
        loop rest {params with prompt= Some prompt}
    | [] ->
        params
  in
  loop (Array.to_list Sys.argv |> List.drop 1) default_params

let parse_vendor str =
  match str with "openai" -> Some OpenAi | "gemini" -> Some Gemini | _ -> None

let run vendor prompt =
  match vendor with
  | OpenAi ->
      let module Run = RunRequest (Openai_agent.OpenAiAgent) in
      Run.run prompt
  | Gemini ->
      let module Run = RunRequest (Gemini_agent.GeminiAgent) in
      Run.run prompt

let run_with_vendor config prompt =
  match parse_vendor config.vendor_name with
  | Some vendor ->
      run vendor prompt
  | None ->
      Printf.eprintf "ERROR: unknown vendor \"%s\"\n" config.vendor_name ;
      exit 1

let () =
  let params = create_params () in
  match params with
  | {prompt= None; _} ->
      usage () ; exit 1
  | {prompt= Some prompt; config} ->
      run_with_vendor config prompt
