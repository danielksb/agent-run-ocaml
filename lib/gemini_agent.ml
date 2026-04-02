type gemini_content =
  | UserText of string
  | RawModelContent of Yojson.Safe.t
  | FunctionResult of {name: string; result: string; id: string option}

let content_to_json = function
  | UserText text ->
      `Assoc
        [ ("role", `String "user")
        ; ("parts", `List [`Assoc [("text", `String text)]]) ]
  | RawModelContent json ->
      json
  | FunctionResult {name; result; id} ->
      let func_resp =
        let base =
          [ ("name", `String name)
          ; ("response", `Assoc [("result", `String result)]) ]
        in
        match id with Some i -> base @ [("id", `String i)] | None -> base
      in
      `Assoc
        [ ("role", `String "user")
        ; ("parts", `List [`Assoc [("functionResponse", `Assoc func_resp)]]) ]

let tool_to_yojson (t : Tool.t) =
  `Assoc
    [ ("name", `String t.name)
    ; ("description", `String t.description)
    ; ("parameters", Tool.parameters_to_yojson t.parameters) ]

module Vendor : Agent.VENDOR = struct
  type msg = gemini_content

  let thought_signatures : string option list ref = ref []

  let user_message p = UserText p

  let request_headers (config : Agent.config) =
    [("Content-Type", "application/json"); ("x-goog-api-key", config.api_key)]

  let request_url (config : Agent.config) =
    config.base_url ^ "/v1beta/models/" ^ config.model_name ^ ":generateContent"

  let request_body (config : Agent.config) tools messages =
    let build_request messages tools =
      let contents = List.map content_to_json messages in
      let tool_decls = List.map tool_to_yojson tools in
      `Assoc
        [ ("contents", `List contents)
        ; ("tools", `List [`Assoc [("functionDeclarations", `List tool_decls)]])
        ]
    in
    build_request messages tools |> Yojson.Safe.to_string

  let parse_response body =
    try
      let json = Yojson.Safe.from_string body in
      let open Yojson.Safe.Util in
      match member "error" json with
      | `Null -> (
        match member "candidates" json |> to_list with
        | [] ->
            Agent.ErrorResponse "No candidates"
        | candidate :: _ -> (
            let content = member "content" candidate in
            let parts = member "parts" content |> to_list in
            let function_calls_rev, new_thought_signatures =
              List.fold_left
                (fun (tcs_rev, sigs_rev) part ->
                  match member "functionCall" part with
                  | `Null ->
                      (tcs_rev, sigs_rev)
                  | fc ->
                      let name = member "name" fc |> to_string in
                      let args = member "args" fc in
                      let thought_signature =
                        match member "thoughtSignature" part with
                        | `String s ->
                            Some s
                        | _ ->
                            None
                      in
                      let id =
                        match member "id" fc with
                        | `String s ->
                            Some s
                        | _ ->
                            None
                      in
                      ( Agent.{name; arguments= args; id} :: tcs_rev
                      , thought_signature :: sigs_rev ) )
                ([], []) parts
            in
            let function_calls = List.rev function_calls_rev in
            thought_signatures := List.rev new_thought_signatures ;
            if function_calls <> [] then
              Agent.ToolCallResponse {content= ""; tool_calls= function_calls}
            else
              let text_parts =
                List.filter_map
                  (fun part ->
                    match member "text" part with
                    | `String t ->
                        Some t
                    | _ ->
                        None )
                  parts
              in
              match text_parts with
              | [] ->
                  Agent.ErrorResponse "No text in response"
              | texts ->
                  Agent.TextResponse (String.concat "" texts) ) )
      | error_json -> (
        match member "message" error_json with
        | `String msg ->
            Agent.ErrorResponse msg
        | _ ->
            Agent.ErrorResponse "Unknown error" )
    with exn -> Agent.ErrorResponse (Printexc.to_string exn)

  let assistant_message _content tool_calls =
    let parts =
      let sigs = !thought_signatures in
      List.mapi
        (fun i (tc : Agent.tool_call) ->
          let thought_signature =
            match List.nth_opt sigs i with Some s -> s | None -> None
          in
          let fc_fields =
            let base = [("name", `String tc.name); ("args", tc.arguments)] in
            match tc.id with
            | Some i ->
                base @ [("id", `String i)]
            | None ->
                base
          in
          match thought_signature with
          | Some ts ->
              `Assoc
                [ ("functionCall", `Assoc fc_fields)
                ; ("thoughtSignature", `String ts) ]
          | None ->
              `Assoc [("functionCall", `Assoc fc_fields)] )
        tool_calls
    in
    let model_content =
      `Assoc [("role", `String "model"); ("parts", `List parts)]
    in
    RawModelContent model_content

  let tool_message (tr : Agent.tool_result) =
    FunctionResult {name= tr.name; result= tr.content; id= tr.id}
end
