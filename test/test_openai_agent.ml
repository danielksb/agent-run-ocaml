open Agentlib

module TestConfig = struct
  let suite_name = "openai_agent"

  let agent_config : Agentlib.Agent.config =
    { model_name= "gpt-4o-mini"
    ; base_url= "https://api.openai.com"
    ; api_key= "TEST_KEY" }

  let response_path = "data/openai/response.json"

  let error_path = "data/openai/error.json"

  let tool_url = "https://api.openai.com/v1/responses"

  let tool_call_response_path = "data/openai/tool_call_response.json"

  let tool_call_request_path = "data/openai/tool_call_request.json"

  let tool_final_response_path = "data/openai/tool_final_response.json"

  let tool_final_request_path = "data/openai/tool_final_request.json"
end

module OpenAiMakeAgent (Http : Http_client.S) : Agent.AGENT =
  Agentlib.Openai_agent.Make (Http) (Test_tools_provider)

module T = Agent_test.Make (OpenAiMakeAgent) (TestConfig)

let tests = T.tests
