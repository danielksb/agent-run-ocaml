(** Identity converters so [@@deriving yojson] can handle raw JSON values. *)
type json = Yojson.Safe.t

let json_to_yojson (x : json) = x

let json_of_yojson (x : Yojson.Safe.t) : (json, string) result = Ok x

type ollama_message =
  | User of string
  | Assistant of {content: string; tool_calls: Agent.tool_call list}
  | ToolResult of Agent.tool_result

type tool_call_function = {name: string; arguments: json}
[@@deriving yojson {strict= false}]

type tool_call = {function_: tool_call_function [@key "function"]}
[@@deriving yojson {strict= false}]

type response_message =
  { role: string
  ; content: string [@default ""]
  ; tool_calls: tool_call list [@default []] }
[@@deriving yojson {strict= false}]

type response = {message: response_message} [@@deriving yojson {strict= false}]

let tool_to_yojson (t : Tool.t) =
  `Assoc
    [ ("type", `String "function")
    ; ( "function"
      , `Assoc
          [ ("name", `String t.name)
          ; ("description", `String t.description)
          ; ("parameters", Tool.parameters_to_yojson t.parameters) ] ) ]

let message_to_yojson = function
  | User content ->
      `Assoc [("role", `String "user"); ("content", `String content)]
  | Assistant {content; tool_calls} ->
      let tc_json =
        List.mapi
          (fun i (tc : Agent.tool_call) ->
            `Assoc
              [ ("type", `String "function")
              ; ( "function"
                , `Assoc
                    [ ("index", `Int i)
                    ; ("name", `String tc.name)
                    ; ("arguments", tc.arguments) ] ) ] )
          tool_calls
      in
      `Assoc
        [ ("role", `String "assistant")
        ; ("content", `String content)
        ; ("tool_calls", `List tc_json) ]
  | ToolResult (tr : Agent.tool_result) ->
      `Assoc
        [ ("role", `String "tool")
        ; ("tool_name", `String tr.name)
        ; ("content", `String tr.content) ]

let build_request model messages tools =
  let msgs_json = List.map message_to_yojson messages in
  let tools_json = List.map tool_to_yojson tools in
  `Assoc
    [ ("model", `String model)
    ; ("messages", `List msgs_json)
    ; ("stream", `Bool false)
    ; ("tools", `List tools_json) ]

let parse_response body =
  try
    let json = Yojson.Safe.from_string body in
    let open Yojson.Safe.Util in
    match member "error" json with
    | `String msg ->
        Agent.ErrorResponse msg
    | `Null -> (
      match response_of_yojson json with
      | Error e ->
          Agent.ErrorResponse ("Json parsing error: " ^ e)
      | Ok resp ->
          let calls =
            List.map
              (fun (tc : tool_call) ->
                Agent.
                  { name= tc.function_.name
                  ; arguments= tc.function_.arguments
                  ; id= None } )
              resp.message.tool_calls
          in
          if calls = [] then Agent.TextResponse resp.message.content
          else
            Agent.ToolCallResponse
              {content= resp.message.content; tool_calls= calls} )
    | _ ->
        Agent.ErrorResponse "Unknown error format"
  with exn -> Agent.ErrorResponse (Printexc.to_string exn)

module Make (Http : Agent.HTTP_CLIENT) (Tools : Tool_registry.PROVIDER) = struct
  type t = {base_url: string; model: string}

  let create (config : Agent.config) =
    {base_url= config.base_url; model= config.model_name}

  let with_url agent url = {agent with base_url= url}

  let agent_loop agent prompt =
    let registry = Tools.registry in
    let tools = Tool_registry.tools registry in
    let headers = [("Content-Type", "application/json")] in
    let url = agent.base_url ^ "/api/chat" in
    let fns : ollama_message Agent.agent_loop_fns =
      { initial_messages= (fun p -> [User p])
      ; build_request_body=
          (fun messages ->
            build_request agent.model messages tools |> Yojson.Safe.to_string )
      ; parse_response
      ; append_assistant=
          (fun messages content tool_calls ->
            messages @ [Assistant {content; tool_calls}] )
      ; append_tool_result= (fun messages tr -> messages @ [ToolResult tr]) }
    in
    Agent.run_agent_loop registry ~post:Http.post ~url ~headers fns prompt

  let send_request = agent_loop
end
