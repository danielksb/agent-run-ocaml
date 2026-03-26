open Agentlib

module TestConfig = struct
  let suite_name = "gemini_agent"

  let create_with_options_arg = "TEST_KEY"

  let response_path = "data/gemini/response.json"

  let error_path = "data/gemini/error.json"

  let tool_url =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"

  let tool_call_response_path = "data/gemini/tool_call_response.json"

  let tool_call_request_path = "data/gemini/tool_call_request.json"

  let tool_final_response_path = "data/gemini/tool_final_response.json"

  let tool_final_request_path = "data/gemini/tool_final_request.json"
end

module GeminiMakeAgent (Http : Agent.HTTP_CLIENT) : Agent.AGENT =
  Agentlib.Gemini_agent.Make (Http) (Test_tools_provider)

module T = Agent_test.Make (GeminiMakeAgent) (TestConfig)

let tests = T.tests
