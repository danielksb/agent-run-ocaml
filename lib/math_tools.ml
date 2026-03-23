let int_params : Tool.parameters =
  { type_= "object"
  ; properties=
      Tool.StringMap.empty
      |> Tool.StringMap.add "a"
           Tool.
             {type_= "integer"; description= Some "The first number"; enum= None}
      |> Tool.StringMap.add "b"
           Tool.
             { type_= "integer"
             ; description= Some "The second number"
             ; enum= None }
  ; required= ["a"; "b"] }

let add_definition : Tool.t =
  { type_= "function"
  ; name= "add"
  ; description= "Add two numbers"
  ; parameters= int_params
  ; strict= true }

let multiply_definition : Tool.t =
  { type_= "function"
  ; name= "multiply"
  ; description= "Multiply two numbers"
  ; parameters= int_params
  ; strict= true }

let extract_ints args =
  let open Yojson.Safe.Util in
  try
    let a = member "a" args |> to_int in
    let b = member "b" args |> to_int in
    Ok (a, b)
  with exn -> Error (Printexc.to_string exn)

let add_run (args : Yojson.Safe.t) =
  Printf.eprintf "Adding arguments: %s\n" (Yojson.Safe.to_string args) ;
  match Tool.validate_arguments add_definition args with
  | Error _ as e ->
      e
  | Ok _ -> (
    match extract_ints args with
    | Ok (a, b) ->
        Ok (string_of_int (a + b))
    | Error e ->
        Error e )

let multiply_run (args : Yojson.Safe.t) =
  Printf.eprintf "Multiplying arguments: %s\n" (Yojson.Safe.to_string args) ;
  match Tool.validate_arguments multiply_definition args with
  | Error _ as e ->
      e
  | Ok _ -> (
    match extract_ints args with
    | Ok (a, b) ->
        Ok (string_of_int (a * b))
    | Error e ->
        Error e )
