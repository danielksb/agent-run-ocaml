open Lwt

type request = {model: string; prompt: string; stream: bool} [@@deriving yojson]

type ollama_response = {response: string}
[@@deriving yojson {strict= false}]

module MakeOllamaAgent (Http : Agent.HTTP_CLIENT) : Agent.AGENT = struct
  type t = {host: string; model: string}

  let create_with_options host = {host; model= "llama3.2"}

  let create () = Ok (create_with_options "http://localhost:11434")

  let response_output response_body =
    let json = response_body |> Yojson.Safe.from_string in
    let error = Yojson.Safe.Util.member "error" json in
    match error with
    | `Null -> (
      match ollama_response_of_yojson json with
      | Error error ->
          Error Agent.{message= "Json parsing error: " ^ error}
      | Ok {response} ->
          Ok Agent.{response} )
    | `String message ->
        Error Agent.{message}
    | _ ->
        Error Agent.{message= "Unknown error format"}

  let send_request agent prompt =
    let headers = [("Content-Type", "application/json")] in
    let body =
      {model= agent.model; prompt; stream= false}
      |> request_to_yojson |> Yojson.Safe.to_string
    in
    let url = agent.host ^ "/api/generate" in
    Http.post ~url ~headers ~body
    >|= fun (code, body_str) ->
    Printf.printf "Response code: %d\n" code ;
    Printf.printf "Body: %s\n" body_str ;
    response_output body_str
end

module OllamaAgent = MakeOllamaAgent (Agent.RealHttpClient)
