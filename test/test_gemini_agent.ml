module Paths = struct
  let suite_name = "gemini_agent"

  let response_path = "data/gemini/response.json"

  let error_path = "data/gemini/error.json"
end

module T = Agent_test.Make (Agentlib.Gemini_agent.Make) (Paths)

let tests = T.tests
