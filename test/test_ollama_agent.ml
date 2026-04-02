open Agentlib

module TestConfig = struct
  let suite_name = "ollama_agent"

  let agent_config : Agentlib.Agent.config =
    { model_name= "functiongemma"
    ; api_key= ""
    ; base_url= "http://localhost:11434" }

  let response_path = "data/ollama/response.json"

  let error_path = "data/ollama/error.json"

  let tool_url = "http://localhost:11434/api/chat"

  let tool_call_response_path = "data/ollama/tool_call_response.json"

  let tool_call_request_path = "data/ollama/tool_call_request.json"

  let tool_final_response_path = "data/ollama/tool_final_response.json"

  let tool_final_request_path = "data/ollama/tool_final_request.json"
end

module OllamaMakeAgent (Http : Http_client.S) : Agent.AGENT =
  Agentlib.Agent.Make (Ollama_agent.Vendor) (Http) (Test_tools_provider)

module T = Agent_test.Make (OllamaMakeAgent) (TestConfig)

let tests = T.tests
