module Paths = struct
  let suite_name = "openai_agent"

  let response_path = "data/openai/response.json"

  let error_path = "data/openai/error.json"
end

module T = Agent_test.Make (Agentlib.Openai_agent.Make) (Paths)

let tests = T.tests
