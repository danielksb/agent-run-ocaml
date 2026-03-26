type agent_response = {response: string} [@@deriving show, eq]

type agent_error = {message: string} [@@deriving show, eq]

type agent_result = (agent_response, agent_error) result

type tool_call = {name: string; arguments: Yojson.Safe.t; id: string option}

type tool_result = {name: string; content: string; id: string option}

type parsed_response =
  | TextResponse of string
  | ToolCallResponse of {content: string; tool_calls: tool_call list}
  | ErrorResponse of string

let execute_tool_call (tool_reg : Tool_registry.t) (tc : tool_call) :
    tool_result =
  let content =
    match Tool_registry.find_handler tool_reg tc.name with
    | Some handler -> (
      match handler tc.arguments with
      | Ok r ->
          r
      | Error e ->
          "Tool error: " ^ e )
    | None ->
        "Unknown tool: " ^ tc.name
  in
  {name= tc.name; content; id= tc.id}

type 'msg agent_loop_fns =
  { initial_messages: string -> 'msg list
  ; build_request_body: 'msg list -> string
  ; parse_response: string -> parsed_response
  ; append_assistant: 'msg list -> string -> tool_call list -> 'msg list
  ; append_tool_result: 'msg list -> tool_result -> 'msg list }

let run_agent_loop tool_registry ~post ~url ~headers fns prompt =
  let open Lwt in
  let rec loop messages =
    let body = fns.build_request_body messages in
    post ~url ~headers ~body
    >>= fun (_code, body_str) ->
    match fns.parse_response body_str with
    | ErrorResponse msg ->
        Lwt.return (Error {message= msg})
    | TextResponse text ->
        Lwt.return (Ok {response= text})
    | ToolCallResponse {content; tool_calls} ->
        let messages = fns.append_assistant messages content tool_calls in
        let tool_results =
          List.map (execute_tool_call tool_registry) tool_calls
        in
        let messages =
          List.fold_left
            (fun msgs tr -> fns.append_tool_result msgs tr)
            messages tool_results
        in
        loop messages
  in
  loop (fns.initial_messages prompt)

module type HTTP_CLIENT = sig
  val post :
       url:string
    -> headers:(string * string) list
    -> body:string
    -> (int * string) Lwt.t
end

module RealHttpClient : HTTP_CLIENT = struct
  open Lwt

  let post ~url ~headers ~body =
    Printf.eprintf "DEBUG: Request body: %s\n" body ;
    let cohttp_headers = Cohttp.Header.of_list headers in
    let cohttp_body = Cohttp_lwt.Body.of_string body in
    Cohttp_lwt_unix.Client.post ~body:cohttp_body ~headers:cohttp_headers
      (Uri.of_string url)
    >>= fun (resp, body) ->
    let code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
    body |> Cohttp_lwt.Body.to_string
    >|= fun body_str ->
    Printf.eprintf "DEBUG: Response code: %d\n" code ;
    Printf.eprintf "DEBUG: Response body: %s\n" body_str ;
    (code, body_str)
end

module type AGENT = sig
  type t

  val create_with_options : string -> t

  val create : unit -> (t, agent_error) result

  val send_request : t -> string -> agent_result Lwt.t

  val agent_loop : t -> string -> agent_result Lwt.t
end
