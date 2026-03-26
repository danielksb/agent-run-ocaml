let definition : Tool.t =
  { type_= "function"
  ; name= "read_file"
  ; description= "Read a single file"
  ; parameters=
      { type_= "object"
      ; properties=
          Tool.StringMap.empty
          |> Tool.StringMap.add "file"
               Tool.
                 { type_= "string"
                 ; description= Some "Path to the file to read."
                 ; enum= None }
      ; required= ["file"] }
  ; strict= true }

let run (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok args ->
      let parsed_file =
        let open Yojson.Safe.Util in
        try
          let dir_name = member "file" args |> to_string in
          Ok dir_name
        with Type_error (msg, _) ->
          Error ("Cannot call tool 'read_file': " ^ msg)
      in
      Result.bind parsed_file (fun file ->
          try Ok (open_in file |> In_channel.input_all)
          with Sys_error _ -> Error ("Cannot read file: " ^ file) )
