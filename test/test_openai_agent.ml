module TestConfig = struct
  let suite_name = "openai_agent"

  let create_with_options_arg = "TEST_KEY"

  let response_path = "data/openai/response.json"

  let error_path = "data/openai/error.json"

  let tool_url = "https://api.openai.com/v1/responses"

  let tool_call_response_path = "data/openai/tool_call_response.json"

  let tool_call_request_path = "data/openai/tool_call_request.json"

  let tool_final_response_path = "data/openai/tool_final_response.json"

  let tool_final_request_path = "data/openai/tool_final_request.json"
end

module T = Agent_test.Make (Agentlib.Openai_agent.Make) (TestConfig)

let tests = T.tests
