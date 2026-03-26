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
                 ; enum= None }
          |> Tool.StringMap.add "content"
               Tool.
                 { type_= "string"
                 ; description= Some "Content to write into the file."
                 ; enum= None }
      ; required= ["file"; "content"] }
  ; strict= true }

let run (args : Yojson.Safe.t) =
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
          Error ("Cannot call tool 'read_file': " ^ msg)
      in
      Result.bind parsed_args (fun (file_name, content) ->
          try
            let out = open_out file_name in
            Out_channel.output_string out content ;
            Out_channel.flush out ;
            Ok ("File " ^ file_name ^ " was successfully written.")
          with Sys_error _ -> Error ("Cannot write file: " ^ file_name) )
