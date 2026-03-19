open Lwt

let default_model = "gpt-4o-mini"

let default_base_url = "https://api.openai.com"

type request = {model: string; input: string} [@@deriving yojson]

type response_output_text =
  {type_: string [@key "type"] (* always "output_text" *); text: string}
[@@deriving yojson {strict= false}]

type response_output_message =
  { type_: string [@key "type"] (* always "message" *)
  ; content: response_output_text list
  ; status: string }
[@@deriving yojson {strict= false}]

type function_call =
  { type_: string [@key "type"] (* always "function_call" *)
  ; name: string
  ; arguments: string }
[@@deriving yojson {strict= false}]

type response_error = {message: string} [@@deriving yojson {strict= false}]

type response = {id: string; output: response_output_message list}
[@@deriving yojson {strict= false}]

module MakeOpenAiAgent (Http : Agent.HTTP_CLIENT) : Agent.AGENT = struct
  type t = {api_key: string; default_model: string; default_base_url: string}

  let create_with_options api_key =
    { api_key
    ; default_model= "gpt-4o-mini"
    ; default_base_url= "https://api.openai.com" }

  let create () =
    match Sys.getenv_opt "OPENAI_API_KEY" with
    | Some api_key ->
        Ok (create_with_options api_key)
    | None ->
        Error Agent.{message= "OPENAI_API_KEY environment variable not set"}

  let response_output response_body =
    let json = response_body |> Yojson.Safe.from_string in
    let error = Yojson.Safe.Util.member "error" json in
    match error with
    | `Null -> (
      match response_of_yojson json with
      | Error error ->
          Error Agent.{message= "Json parsing error: " ^ error}
      | Ok {output= []} ->
          Error Agent.{message= "No output"}
      | Ok {output= msg :: _; _} -> (
        match msg.content with
        | [] ->
            Error Agent.{message= "No content in message"}
        | text :: _ ->
            Ok Agent.{response= text.text} ) )
    | _ -> (
      match response_error_of_yojson error with
      | Error error ->
          Error Agent.{message= "Json parsing error: " ^ error}
      | Ok {message} ->
          Error Agent.{message} )

  let send_request agent prompt =
    let headers =
      [ ("Content-Type", "application/json")
      ; ("Authorization", "Bearer " ^ agent.api_key) ]
    in
    let body =
      {model= default_model; input= prompt}
      |> request_to_yojson |> Yojson.Safe.to_string
    in
    let url = default_base_url ^ "/v1/responses" in
    Http.post ~url ~headers ~body
    >|= fun (code, body_str) ->
    Printf.printf "Response code: %d\n" code ;
    Printf.printf "Body: %s\n" body_str ;
    response_output body_str
end

module OpenAiAgent = MakeOpenAiAgent (Agent.RealHttpClient)
