open Agentlib

let string_result_testable =
  Alcotest.(result (testable Yojson.Safe.pp Yojson.Safe.equal) string)

let weather_tool : Tool.t =
  { type_= "function"
  ; name= "test_tool"
  ; description= "A test tool"
  ; parameters=
      { type_= "object"
      ; properties=
          Tool.StringMap.empty
          |> Tool.StringMap.add "location"
               Tool.{type_= "string"; description= None; enum= None}
          |> Tool.StringMap.add "unit"
               Tool.{type_= "string"; description= None; enum= None}
      ; required= ["location"] }
  ; strict= false }

let no_required_tool : Tool.t =
  { type_= "function"
  ; name= "noop"
  ; description= "A tool with no required params"
  ; parameters= {type_= "object"; properties= Tool.StringMap.empty; required= []}
  ; strict= false }

let test_valid_all_args () =
  let args =
    `Assoc [("location", `String "Boston, MA"); ("unit", `String "celsius")]
  in
  Alcotest.(check string_result_testable)
    "accepts all args" (Ok args)
    (Tool.validate_arguments weather_tool args)

let test_valid_only_required () =
  let args = `Assoc [("location", `String "Berlin")] in
  Alcotest.(check string_result_testable)
    "accepts only required" (Ok args)
    (Tool.validate_arguments weather_tool args)

let test_missing_required () =
  let args = `Assoc [("unit", `String "celsius")] in
  Alcotest.(check string_result_testable)
    "rejects missing location" (Error "missing required argument: location")
    (Tool.validate_arguments weather_tool args)

let test_null_required () =
  let args = `Assoc [("location", `Null)] in
  Alcotest.(check string_result_testable)
    "rejects null location" (Error "missing required argument: location")
    (Tool.validate_arguments weather_tool args)

let test_not_an_object () =
  let args = `String "not an object" in
  Alcotest.(check string_result_testable)
    "rejects non-object" (Error "arguments must be a JSON object")
    (Tool.validate_arguments weather_tool args)

let test_empty_object () =
  let args = `Assoc [] in
  Alcotest.(check string_result_testable)
    "rejects empty object" (Error "missing required argument: location")
    (Tool.validate_arguments weather_tool args)

let test_no_required_field () =
  let args = `Assoc [] in
  Alcotest.(check string_result_testable)
    "accepts empty args when no required" (Ok args)
    (Tool.validate_arguments no_required_tool args)

let test_tool_to_yojson () =
  let json = Tool.to_yojson weather_tool in
  let name = Yojson.Safe.Util.(member "name" json |> to_string) in
  let req =
    Yojson.Safe.Util.(
      member "parameters" json |> member "required" |> to_list
      |> List.map to_string )
  in
  Alcotest.(check string) "name roundtrips" "test_tool" name ;
  Alcotest.(check (list string)) "required roundtrips" ["location"] req

let test_tool_roundtrip () =
  let json = Tool.to_yojson weather_tool in
  let result = Tool.of_yojson json in
  Alcotest.(check bool) "roundtrip succeeds" true (Result.is_ok result) ;
  let tool' = Result.get_ok result in
  Alcotest.(check string) "name preserved" weather_tool.name tool'.name ;
  Alcotest.(check (list string))
    "required preserved" weather_tool.parameters.required
    tool'.parameters.required ;
  Alcotest.(check bool)
    "properties preserved"
    (Tool.StringMap.mem "location" tool'.parameters.properties)
    true

let tests =
  ( "tool"
  , [ Alcotest.test_case "all arguments present" `Quick test_valid_all_args
    ; Alcotest.test_case "only required argument" `Quick
        test_valid_only_required
    ; Alcotest.test_case "missing required argument" `Quick
        test_missing_required
    ; Alcotest.test_case "null required argument" `Quick test_null_required
    ; Alcotest.test_case "non-object arguments" `Quick test_not_an_object
    ; Alcotest.test_case "empty object with required" `Quick test_empty_object
    ; Alcotest.test_case "no required field in schema" `Quick
        test_no_required_field
    ; Alcotest.test_case "to_yojson produces correct JSON" `Quick
        test_tool_to_yojson
    ; Alcotest.test_case "yojson roundtrip" `Quick test_tool_roundtrip ] )
