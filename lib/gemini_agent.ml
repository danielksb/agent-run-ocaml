open Lwt

type request_part = {text: string} [@@deriving yojson]

type request_content = {parts: request_part list} [@@deriving yojson]

type request = {contents: request_content list} [@@deriving yojson]

type response_error = {message: string} [@@deriving yojson {strict= false}]

type response_part = {text: string} [@@deriving yojson {strict= false}]

type response_content = {parts: response_part list}
[@@deriving yojson {strict= false}]

type response_candidate = {content: response_content}
[@@deriving yojson {strict= false}]

type response = {candidates: response_candidate list}
[@@deriving yojson {strict= false}]

module MakeGeminiAgent (Http : Agent.HTTP_CLIENT) : Agent.AGENT = struct
  type t = {api_key: string; model: string; base_url: string}

  let create_with_options api_key =
    { api_key
    ; model= "gemini-flash-latest"
    ; base_url= "https://generativelanguage.googleapis.com" }

  let create () =
    match Sys.getenv_opt "GEMINI_API_KEY" with
    | Some api_key ->
        Ok (create_with_options api_key)
    | None ->
        Error Agent.{message= "GEMINI_API_KEY environment variable not set"}

  let response_output response_body =
    let json = response_body |> Yojson.Safe.from_string in
    let error = Yojson.Safe.Util.member "error" json in
    match error with
    | `Null -> (
      match response_of_yojson json with
      | Error error ->
          Error Agent.{message= "Json parsing error: " ^ error}
      | Ok {candidates= []} ->
          Error Agent.{message= "No candidates"}
      | Ok {candidates= candidate :: _; _} -> (
        match candidate.content.parts with
        | [] ->
            Error Agent.{message= "No content in message"}
        | part :: _ ->
            Ok Agent.{response= part.text} ) )
    | _ -> (
      match response_error_of_yojson error with
      | Error error ->
          Error Agent.{message= "Json parsing error: " ^ error}
      | Ok {message} ->
          Error Agent.{message} )

  let send_request agent prompt =
    let headers =
      [("Content-Type", "application/json"); ("x-goog-api-key", agent.api_key)]
    in
    let body =
      {contents= [{parts= [{text= prompt}]}]}
      |> request_to_yojson |> Yojson.Safe.to_string
    in
    let url =
      agent.base_url ^ "/v1beta/models/" ^ agent.model ^ ":generateContent"
    in
    Http.post ~url ~headers ~body
    >|= fun (code, body_str) ->
    Printf.printf "Response code: %d\n" code ;
    Printf.printf "Body: %s\n" body_str ;
    response_output body_str
end

module GeminiAgent = MakeGeminiAgent (Agent.RealHttpClient)
