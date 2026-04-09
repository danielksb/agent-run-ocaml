let definition : Tool.t =
  { type_= "function"
  ; name= "write_file"
  ; description=
      "Write text to a single file. Creates the file if it does not exist yet. \
       Overwrites previous content."
  ; parameters=
      { type_= "object"
      ; properties=
          Tool.StringMap.empty
          |> Tool.StringMap.add "file"
               Tool.
                 { type_= "string"
                 ; description= Some "Path to the file to write."
                 ; enum= None
                 ; items= None }
          |> Tool.StringMap.add "content"
               Tool.
                 { type_= "string"
                 ; description= Some "Content to write into the file."
                 ; enum= None
                 ; items= None }
      ; required= ["file"; "content"] }
  ; strict= true }

let run (tool_context : Tool.tool_context) (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok args ->
      let parsed_args =
        try
          let file_name =
            Yojson.Safe.Util.member "file" args |> Yojson.Safe.Util.to_string
          in
          let content =
            Yojson.Safe.Util.member "content" args |> Yojson.Safe.Util.to_string
          in
          Ok (file_name, content)
        with Yojson.Safe.Util.Type_error (msg, _) ->
          Error ("Cannot call tool 'write_file': " ^ msg)
      in
      let working_directory = tool_context.working_directory in
      Result.bind parsed_args (fun (file_name, content) ->
          Result.bind (Path_guard.guard_path ~root:working_directory file_name)
            (fun safe_file ->
              try
                Out_channel.with_open_text safe_file (fun out ->
                    Out_channel.output_string out content ;
                    Out_channel.flush out ;
                    Ok ("File " ^ file_name ^ " was successfully written.") )
              with Sys_error _ -> Error ("Cannot write file: " ^ file_name) ) )
