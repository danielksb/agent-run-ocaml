(** common configuration for all agent implementations *)
type config = {model_name: string; api_key: string; base_url: string}

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
    tool_result Lwt.t =
  let open Lwt in
  Logging.verbose
    (Printf.sprintf "Calling tool \"%s\" with %s" tc.name
       (Yojson.Safe.to_string tc.arguments) ) ;
  let wrap_content content = return {name= tc.name; content; id= tc.id} in
  match Tool_registry.find_handler tool_reg tc.name with
  | Some handler -> (
      handler tc.arguments
      >>= fun result ->
      match result with
      | Ok r ->
          wrap_content r
      | Error e ->
          wrap_content ("Tool error: " ^ e) )
  | None ->
      wrap_content ("Unknown tool: " ^ tc.name)

type 'msg agent_loop_fns =
  { initial_messages: string -> 'msg list
  ; build_request_body: 'msg list -> string
  ; parse_response: string -> parsed_response
  ; append_assistant: 'msg list -> string -> tool_call list -> 'msg list
  ; append_tool_result: 'msg list -> tool_result -> 'msg list }

let run_agent_loop tool_registry ~post ~url ~headers fns prompt =
  let open Lwt in
  let rec loop step messages =
    let body = fns.build_request_body messages in
    post ~url ~headers ~body
    >>= fun (_code, body_str) ->
    match fns.parse_response body_str with
    | ErrorResponse msg ->
        Logging.verbose
          (Printf.sprintf "step %d model response type: error" step) ;
        Lwt.return (Error {message= msg})
    | TextResponse text ->
        Logging.verbose
          (Printf.sprintf "step %d model response type: final_text" step) ;
        Lwt.return (Ok {response= text})
    | ToolCallResponse {content; tool_calls} ->
        Logging.verbose
          (Printf.sprintf "step %d model response type: tool_call" step) ;
        let messages = fns.append_assistant messages content tool_calls in
        let tool_results =
          List.map (execute_tool_call tool_registry) tool_calls
        in
        Lwt.all tool_results
        >>= fun results ->
        let messages =
          List.fold_left
            (fun msgs tr -> fns.append_tool_result msgs tr)
            messages results
        in
        loop (step + 1) messages
  in
  loop 1 (fns.initial_messages prompt)

module type AGENT = sig
  type t

  val create : config -> t

  val send_request : t -> string -> agent_result Lwt.t

  val agent_loop : t -> string -> agent_result Lwt.t
end
