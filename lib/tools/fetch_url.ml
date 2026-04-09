module Make (Http : Http_client.S) = struct
  let definition : Tool.t =
    { type_= "function"
    ; name= "fetch_url"
    ; description= "Fetch an HTTP(S) URL and return the response body as text."
    ; parameters=
        { type_= "object"
        ; properties=
            Tool.StringMap.empty
            |> Tool.StringMap.add "url"
                 Tool.
                   { type_= "string"
                   ; description= Some "HTTP or HTTPS URL to fetch."
                   ; enum= None
                   ; items= None }
        ; required= ["url"] }
    ; strict= true }

  let create_error message = Error ("Cannot call tool 'fetch_url': " ^ message)

  let parse_url args =
    try Ok (Yojson.Safe.Util.member "url" args |> Yojson.Safe.Util.to_string)
    with Yojson.Safe.Util.Type_error (msg, _) -> create_error msg

  let validate_scheme raw_url =
    let uri = Uri.of_string raw_url in
    match Uri.scheme uri with
    | Some "http" | Some "https" ->
        Ok uri
    | Some scheme ->
        create_error
          (Printf.sprintf "unsupported scheme '%s' (expected http or https)"
             scheme )
    | None ->
        create_error "URL must include a scheme (http or https)"

  let fetch_body uri =
    let get_call = Http.get ~url:(Uri.to_string uri) ~headers:[] in
    Lwt.( >>= ) get_call (fun (status, body) ->
        if status >= 200 && status < 300 then Lwt.return @@ Ok body
        else
          Lwt.return
          @@ create_error ("response status is " ^ Int.to_string status) )

  let run (tool_context : Tool.tool_context) (args : Yojson.Safe.t) =
    match Tool.validate_arguments definition args with
    | Error _ as e ->
        Lwt.return e
    | Ok args -> (
      match Result.bind (parse_url args) validate_scheme with
      | Ok url ->
          fetch_body url
      | Error _ as e ->
          Lwt.return e )
end

module Default = Make (Http_client.Default)

let definition = Default.definition

let run = Default.run
