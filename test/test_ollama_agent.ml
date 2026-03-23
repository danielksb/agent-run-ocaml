open Agentlib

module Paths = struct
  let suite_name = "ollama_agent"

  let response_path = "data/ollama/response.json"

  let error_path = "data/ollama/error.json"

  let tool_call_response_path = "data/ollama/tool_call_response.json"

  let tool_final_response_path = "data/ollama/tool_final_response.json"
end

module OllamaMakeAgent (Http : Agent.HTTP_CLIENT) : Agent.AGENT =
  Ollama_agent.Make (Http)

module T = Agent_test.Make (OllamaMakeAgent) (Paths)

let handler_result_testable = Alcotest.(result string string)

let test_add_tool () =
  let args = `Assoc [("a", `Int 11434); ("b", `Int 12341)] in
  Alcotest.(check handler_result_testable)
    "add returns correct sum" (Ok "23775") (Math_tools.add_run args)

let test_multiply_tool () =
  let args = `Assoc [("a", `Int 23775); ("b", `Int 412)] in
  Alcotest.(check handler_result_testable)
    "multiply returns correct product" (Ok "9795300")
    (Math_tools.multiply_run args)

let test_add_missing_args () =
  let args = `Assoc [("a", `Int 1)] in
  Alcotest.(check handler_result_testable)
    "add rejects missing argument" (Error "missing required argument: b")
    (Math_tools.add_run args)

let tests =
  let name, base_tests = T.tests in
  ( name
  , base_tests
    @ [ Alcotest.test_case "add tool" `Quick test_add_tool
      ; Alcotest.test_case "multiply tool" `Quick test_multiply_tool
      ; Alcotest.test_case "add tool missing args" `Quick test_add_missing_args
      ] )
