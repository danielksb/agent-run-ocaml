let definition : Tool.t =
  { type_= "function"
  ; name= "list_files"
  ; description= "List files in a given directory."
  ; parameters=
      { type_= "object"
      ; properties=
          Tool.StringMap.empty
          |> Tool.StringMap.add "directory"
               Tool.
                 { type_= "string"
                 ; description= Some "Directory which files to list."
                 ; enum= None }
      ; required= ["directory"] }
  ; strict= true }

let rec find_all_files file =
  try
    if Sys.is_directory file && not (String.starts_with ~prefix:".git" file)
    then
      Sys.readdir file |> Array.to_seq
      |> Seq.map (fun child -> file ^ "/" ^ child)
      |> Seq.concat_map find_all_files
    else Seq.return file
  with Sys_error _ -> Seq.empty

let run (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok args ->
      let parsed_dir =
        try
          let dir_name =
            Yojson.Safe.Util.member "directory" args
            |> Yojson.Safe.Util.to_string
          in
          Ok dir_name
        with Yojson.Safe.Util.Type_error (msg, _) ->
          Error ("Cannot call tool 'list_files': " ^ msg)
      in
      parsed_dir
      |> Result.map (fun dir ->
          find_all_files dir |> List.of_seq |> String.concat "\n" )
