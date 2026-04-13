let definition : Tool.t =
  { type_= "function"
  ; name= "edit_file"
  ; description= "Replaces a string in a file with another string."
  ; parameters=
      { type_= "object"
      ; properties=
          Tool.StringMap.empty
          |> Tool.StringMap.add "file"
               Tool.
                 { type_= "string"
                 ; description= Some "Path to the file to edit."
                 ; enum= None
                 ; items= None }
          |> Tool.StringMap.add "old_string"
               Tool.
                 { type_= "string"
                 ; description= Some "Old string to be replaced by new string"
                 ; enum= None
                 ; items= None }
          |> Tool.StringMap.add "new_string"
               Tool.
                 { type_= "string"
                 ; description= Some "New string to replace old string."
                 ; enum= None
                 ; items= None }
          |> Tool.StringMap.add "replace_all"
               Tool.
                 { type_= "boolean"
                 ; description=
                     Some
                       "Set to true if all occurrences of new_string should be \
                        replaced. If set to false only the first occurence is \
                        replaced."
                 ; enum= None
                 ; items= None }
      ; required= ["file"; "old_string"; "new_string"; "replace_all"] }
  ; strict= true }

let replace_content ~content ~old_string ~new_string ~replace_all =
  let replace = if replace_all then Str.global_replace else Str.replace_first in
  replace (Str.regexp_string old_string) new_string content

let run (tool_context : Tool.tool_context) (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok args -> (
      let parsed_args =
        try
          let file_name =
            Yojson.Safe.Util.member "file" args |> Yojson.Safe.Util.to_string
          in
          let old_string =
            Yojson.Safe.Util.member "old_string" args
            |> Yojson.Safe.Util.to_string
          in
          let new_string =
            Yojson.Safe.Util.member "new_string" args
            |> Yojson.Safe.Util.to_string
          in
          let replace_all =
            Yojson.Safe.Util.member "replace_all" args
            |> Yojson.Safe.Util.to_bool
          in
          Ok (file_name, old_string, new_string, replace_all)
        with Yojson.Safe.Util.Type_error (msg, _) ->
          Error ("Cannot call tool 'edit_file': " ^ msg)
      in
      let working_directory = tool_context.working_directory in
      let ( let* ) = Result.bind in
      let* file_name, old_string, new_string, replace_all = parsed_args in
      let* safe_file =
        Path_guard.guard_path ~root:working_directory file_name
      in
      try
        let content =
          In_channel.with_open_text safe_file In_channel.input_all
        in
        let replaced_content =
          replace_content ~content ~old_string ~new_string ~replace_all
        in
        Out_channel.with_open_text safe_file (fun out ->
            Out_channel.output_string out replaced_content ;
            Out_channel.flush out ;
            Ok ("File " ^ file_name ^ " was successfully written.") )
      with Sys_error _ -> Error ("Cannot edit file: " ^ file_name) )
