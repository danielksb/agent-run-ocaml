module Paths = struct
  let suite_name = "gemini_agent"

  let response_path = "data/gemini/response.json"

  let error_path = "data/gemini/error.json"

  let tool_call_response_path = "data/gemini/tool_call_response.json"

  let tool_final_response_path = "data/gemini/tool_final_response.json"
end

module T = Agent_test.Make (Agentlib.Gemini_agent.Make) (Paths)

let tests = T.tests
