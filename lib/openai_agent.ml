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

type response =
  {id: string; error: Yojson.Safe.t option; output: response_output_message list}
[@@deriving yojson {strict= false}]

type agent_response = {response: string}

type agent_error = {message: string}

let parse_response response =
  response |> Yojson.Safe.from_string |> response_of_yojson

let response_output response =
  let res = parse_response response in
  match res with
  | Error error ->
      Error {message= error}
  | Ok {error= Some error_obj; _} ->
      Error {message= Yojson.Safe.to_string error_obj}
  | Ok {output= []; _} ->
      Error {message= "No output"}
  | Ok {output= msg :: _; _} -> (
    match msg.content with
    | [] ->
        Error {message= "No content in message"}
    | text :: _ ->
        Ok {response= text.text} )

let send_request prompt api_key =
  let headers =
    Cohttp.Header.of_list
      [ ("Content-Type", "application/json")
      ; ("Authorization", "Bearer " ^ api_key) ]
  in
  let body =
    {model= default_model; input= prompt}
    |> request_to_yojson |> Yojson.Safe.to_string |> Cohttp_lwt.Body.of_string
  in
  let url = default_base_url ^ "/v1/responses" in
  Cohttp_lwt_unix.Client.post ~body ~headers (Uri.of_string url)
  >>= fun (resp, body) ->
  let code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
  Printf.printf "Response code: %d\n" code ;
  Printf.printf "Headers: %s\n"
    (Cohttp.Response.headers resp |> Cohttp.Header.to_string) ;
  body |> Cohttp_lwt.Body.to_string
  >|= fun b ->
  Printf.printf "Body: %s\n" b ;
  response_output b
