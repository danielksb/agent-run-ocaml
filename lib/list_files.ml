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

let run (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok args ->
      let dir =
        Yojson.Safe.Util.member "directory" args |> Yojson.Safe.Util.to_string
      in
      let check_exists =
       fun d ->
        if Sys.file_exists d then Ok d
        else Error ("Cannot list files: " ^ d ^ " does not exist")
      in
      let check_dir =
       fun d ->
        if Sys.is_directory d then Ok d
        else Error ("Cannot list files: " ^ dir ^ " is not a directory")
      in
      let read_dir =
       fun d -> Sys.readdir dir |> Array.to_list |> String.concat "\n"
      in
      Result.bind (check_exists dir) check_dir |> Result.map read_dir
