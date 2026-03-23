type openai_input_item =
  | UserMessage of string
  | RawOutputItems of Yojson.Safe.t list
  | ToolOutput of {call_id: string; output: string}

let tool_to_yojson (t : Tool.t) =
  let parameters =
    `Assoc
      [ ("type", `String t.parameters.type_)
      ; ( "properties"
        , Tool.string_map_to_yojson Tool.property_to_yojson
            t.parameters.properties )
      ; ("required", `List (List.map (fun s -> `String s) t.parameters.required))
      ; ("additionalProperties", `Bool false) ]
  in
  `Assoc
    [ ("type", `String t.type_)
    ; ("name", `String t.name)
    ; ("description", `String t.description)
    ; ("parameters", parameters)
    ; ("strict", `Bool t.strict) ]

let item_to_json_list = function
  | UserMessage content ->
      [`Assoc [("role", `String "user"); ("content", `String content)]]
  | RawOutputItems items ->
      items
  | ToolOutput {call_id; output} ->
      [ `Assoc
          [ ("type", `String "function_call_output")
          ; ("call_id", `String call_id)
          ; ("output", `String output) ] ]

let build_request model messages tools =
  let input_items = List.concat_map item_to_json_list messages in
  let tools_json = List.map tool_to_yojson tools in
  `Assoc
    [ ("model", `String model)
    ; ("input", `List input_items)
    ; ("tools", `List tools_json) ]

let parse_response body =
  try
    let json = Yojson.Safe.from_string body in
    let open Yojson.Safe.Util in
    match member "error" json with
    | `Null -> (
        let output = member "output" json |> to_list in
        let function_calls =
          List.filter_map
            (fun item ->
              match member "type" item with
              | `String "function_call" ->
                  let call_id = member "call_id" item |> to_string in
                  let name = member "name" item |> to_string in
                  let args_str = member "arguments" item |> to_string in
                  let arguments = Yojson.Safe.from_string args_str in
                  Some Agent.{name; arguments; id= Some call_id}
              | _ ->
                  None )
            output
        in
        if function_calls <> [] then
          Agent.ToolCallResponse {content= ""; tool_calls= function_calls}
        else
          let text =
            List.find_map
              (fun item ->
                match member "type" item with
                | `String "message" ->
                    let content_parts = member "content" item |> to_list in
                    List.find_map
                      (fun part ->
                        match member "type" part with
                        | `String "output_text" ->
                            Some (member "text" part |> to_string)
                        | _ ->
                            None )
                      content_parts
                | _ ->
                    None )
              output
          in
          match text with
          | Some t ->
              Agent.TextResponse t
          | None ->
              Agent.ErrorResponse "No output text found" )
    | error_json -> (
      match member "message" error_json with
      | `String msg ->
          Agent.ErrorResponse msg
      | _ ->
          Agent.ErrorResponse "Unknown error" )
  with exn -> Agent.ErrorResponse (Printexc.to_string exn)

module Make (Http : Agent.HTTP_CLIENT) : Agent.AGENT = struct
  type t = {api_key: string; model: string; base_url: string}

  let create_with_options api_key =
    {api_key; model= "gpt-4o-mini"; base_url= "https://api.openai.com"}

  let create () =
    match Sys.getenv_opt "OPENAI_API_KEY" with
    | Some api_key ->
        Ok (create_with_options api_key)
    | None ->
        Error Agent.{message= "OPENAI_API_KEY environment variable not set"}

  let agent_loop agent prompt =
    let tools = Tool_registry.tools () in
    let headers =
      [ ("Content-Type", "application/json")
      ; ("Authorization", "Bearer " ^ agent.api_key) ]
    in
    let url = agent.base_url ^ "/v1/responses" in
    let fns : openai_input_item Agent.agent_loop_fns =
      { initial_messages= (fun p -> [UserMessage p])
      ; build_request_body=
          (fun messages ->
            build_request agent.model messages tools |> Yojson.Safe.to_string )
      ; parse_response
      ; append_assistant=
          (fun messages _content tool_calls ->
            let fc_items =
              List.map
                (fun (tc : Agent.tool_call) ->
                  `Assoc
                    [ ("type", `String "function_call")
                    ; ("call_id", `String (Option.value tc.id ~default:""))
                    ; ("name", `String tc.name)
                    ; ("arguments", `String (Yojson.Safe.to_string tc.arguments))
                    ] )
                tool_calls
            in
            messages @ [RawOutputItems fc_items] )
      ; append_tool_result=
          (fun messages (tr : Agent.tool_result) ->
            messages
            @ [ ToolOutput
                  {call_id= Option.value tr.id ~default:""; output= tr.content}
              ] ) }
    in
    Agent.run_agent_loop ~post:Http.post ~url ~headers fns prompt

  let send_request = agent_loop
end
