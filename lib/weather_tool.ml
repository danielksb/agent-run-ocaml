let definition : Tool.t =
  { type_= "function"
  ; name= "get_weather"
  ; description= "Get the current weather for a location."
  ; parameters=
      { type_= "object"
      ; properties=
          Tool.StringMap.empty
          |> Tool.StringMap.add "location"
               Tool.
                 { type_= "string"
                 ; description= Some "City and region, e.g. Boston, MA"
                 ; enum= None }
          |> Tool.StringMap.add "unit"
               Tool.
                 { type_= "string"
                 ; description= Some "Temperature unit"
                 ; enum= Some ["celsius"; "fahrenheit"] }
      ; required= ["location"; "unit"] }
  ; strict= true }

(** [run args] validates required arguments, then returns a static test string. *)
let run (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      e
  | Ok _ ->
      Ok "Test weather: 22°C, partly cloudy (static response for get_weather)."
