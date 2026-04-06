open Agentlib

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
                 ; enum= None
                 ; items= None }
          |> Tool.StringMap.add "unit"
               Tool.
                 { type_= "string"
                 ; description= Some "Temperature unit"
                 ; enum= Some ["celsius"; "fahrenheit"]
                 ; items= None }
      ; required= ["location"; "unit"] }
  ; strict= true }

let run (_context : Tool_registry.tool_context) (args : Yojson.Safe.t) =
  match Tool.validate_arguments definition args with
  | Error _ as e ->
      Lwt.return e
  | Ok _ ->
      Lwt.return (Ok "Test weather: 22\194\176C.")
