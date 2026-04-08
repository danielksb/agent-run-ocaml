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

let find_substring ~from text pattern =
  let text_len = String.length text in
  let pattern_len = String.length pattern in
  let rec loop idx =
    if idx + pattern_len > text_len then None
    else if String.sub text idx pattern_len = pattern then Some idx
    else loop (idx + 1)
  in
  loop from

let replace_content ~content ~old_string ~new_string ~replace_all =
  let old_len = String.length old_string in
  if old_len = 0 then Error "Cannot edit file: old_string cannot be empty"
  else
    let content_len = String.length content in
    if replace_all then (
      let buffer = Buffer.create content_len in
      let rec add_chunks from =
        match find_substring ~from content old_string with
        | None ->
            Buffer.add_substring buffer content from (content_len - from)
        | Some idx ->
            Buffer.add_substring buffer content from (idx - from) ;
            Buffer.add_string buffer new_string ;
            add_chunks (idx + old_len)
      in
      add_chunks 0 ;
      Ok (Buffer.contents buffer) )
    else
      match find_substring ~from:0 content old_string with
      | None ->
          Ok content
      | Some idx ->
          let prefix = String.sub content 0 idx in
          let suffix_start = idx + old_len in
          let suffix_len = content_len - suffix_start in
          let suffix = String.sub content suffix_start suffix_len in
          Ok (prefix ^ new_string ^ suffix)

let run ?(working_directory = Sys.getcwd ()) (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok args ->
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
      Result.bind parsed_args
        (fun (file_name, old_string, new_string, replace_all) ->
          Result.bind (Path_guard.guard_path ~root:working_directory file_name)
            (fun safe_file ->
              try
                let content =
                  In_channel.with_open_text safe_file In_channel.input_all
                in
                let replaced_content =
                  replace_content ~content ~old_string ~new_string ~replace_all
                in
                Result.bind replaced_content (fun updated_content ->
                    Out_channel.with_open_text safe_file (fun out ->
                        Out_channel.output_string out updated_content ;
                        Out_channel.flush out ;
                        Ok ("File " ^ file_name ^ " was successfully written.")
                    ))
              with Sys_error _ -> Error ("Cannot edit file: " ^ file_name) ) )
