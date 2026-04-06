type config =
  { model_name: string
  ; api_key: string
  ; base_url: string
  ; tool_context: Tool_registry.tool_context }

type agent_response = {response: string} [@@deriving show, eq]

type agent_error = {message: string} [@@deriving show, eq]

type agent_result = (agent_response, agent_error) result

module type AGENT = sig
  type t

  val create : config -> t

  val send_request : t -> string -> agent_result Lwt.t
end

type tool_call = {name: string; arguments: Yojson.Safe.t; id: string option}

type tool_result = {name: string; content: string; id: string option}

type parsed_response =
  | TextResponse of string
  | ToolCallResponse of {content: string; tool_calls: tool_call list}
  | ErrorResponse of string

module type VENDOR = sig
  type msg

  val user_message : string -> msg

  val assistant_message : string -> tool_call list -> msg

  val tool_message : tool_result -> msg

  val request_headers : config -> (string * string) list

  val request_url : config -> string

  val request_body : config -> Tool.t list -> msg list -> string

  val parse_response : string -> parsed_response
end

module Make
    (Vendor : VENDOR)
    (Http : Http_client.S)
    (Tools : Tool_registry.PROVIDER) =
struct
  type t = config

  let create (config : config) = config

  let execute_tool_call (tool_reg : Tool_registry.t)
      (tool_context : Tool_registry.tool_context) (tc : tool_call) :
      tool_result Lwt.t =
    let open Lwt in
    Logging.verbose
      (Printf.sprintf "Calling tool \"%s\" with %s" tc.name
         (Yojson.Safe.to_string tc.arguments) ) ;
    let wrap_content content = return {name= tc.name; content; id= tc.id} in
    match Tool_registry.find_handler tool_reg tc.name with
    | Some handler -> (
        handler tool_context tc.arguments
        >>= fun result ->
        match result with
        | Ok r ->
            wrap_content r
        | Error e ->
            wrap_content ("Tool error: " ^ e) )
    | None ->
        wrap_content ("Unknown tool: " ^ tc.name)

  let send_request (agent : t) prompt =
    let open Lwt in
    let headers = Vendor.request_headers agent in
    let url = Vendor.request_url agent in
    let registry = Tools.registry in
    let tool_context = agent.tool_context in
    let tools = Tool_registry.tools registry in
    let rec loop step messages =
      let body = Vendor.request_body agent tools messages in
      Http.post ~url ~headers ~body
      >>= fun (_code, body_str) ->
      match Vendor.parse_response body_str with
      | ErrorResponse msg ->
          Logging.verbose
            (Printf.sprintf "step %d model response error: %s" step msg) ;
          Lwt.return (Error {message= msg})
      | TextResponse text ->
          Logging.verbose
            (Printf.sprintf "step %d model response final_text: %s" step text) ;
          Lwt.return (Ok {response= text})
      | ToolCallResponse {content; tool_calls} ->
          Logging.verbose
            (Printf.sprintf "step %d model response tool_call" step) ;
          let assistant_msg = Vendor.assistant_message content tool_calls in
          let messages = messages @ [assistant_msg] in
          let tool_results =
            List.map (execute_tool_call registry tool_context) tool_calls
          in
          Lwt.all tool_results
          >>= fun results ->
          let messages =
            List.fold_left
              (fun msgs tr -> msgs @ [Vendor.tool_message tr])
              messages results
          in
          loop (step + 1) messages
    in
    loop 1 [Vendor.user_message prompt]
end
