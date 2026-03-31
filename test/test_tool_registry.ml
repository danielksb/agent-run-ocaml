open Agentlib

let testable_string_list = Alcotest.(list string)

let test_weather_only_profile_has_only_weather_tool () =
  let registry =
    Tool_registry.empty
    |> Tool_registry.add_tool ~tool:Mock_weather_tool.definition
         ~run:Mock_weather_tool.run
  in
  let tool_names =
    Tool_registry.tools registry |> List.map (fun (tool : Tool.t) -> tool.name)
  in
  Alcotest.(check testable_string_list)
    "only get_weather is registered in test registry" ["get_weather"] tool_names

let test_weather_only_profile_handler_availability () =
  let registry =
    Tool_registry.empty
    |> Tool_registry.add_tool ~tool:Mock_weather_tool.definition
         ~run:Mock_weather_tool.run
  in
  let weather_args =
    `Assoc [("location", `String "Berlin"); ("unit", `String "celsius")]
  in
  let weather_result =
    match Tool_registry.find_handler registry "get_weather" with
    | Some run ->
        Lwt_main.run (run weather_args)
    | None ->
        Error "missing get_weather handler"
  in
  let weather_output =
    match weather_result with
    | Ok s ->
        s
    | Error e ->
        Alcotest.fail ("weather handler should succeed, got: " ^ e)
  in
  Alcotest.(check bool)
    "weather output prefix" true
    (String.starts_with ~prefix:"Test weather:" weather_output) ;
  Alcotest.(check bool)
    "read_file is not registered" false
    (Option.is_some (Tool_registry.find_handler registry "read_file"))

let tests =
  ( "tool_registry"
  , [ Alcotest.test_case "test registry tools" `Quick
        test_weather_only_profile_has_only_weather_tool
    ; Alcotest.test_case "test registry handler availability" `Quick
        test_weather_only_profile_handler_availability ] )
