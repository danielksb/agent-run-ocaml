module Paths = struct
  let suite_name = "ollama_agent"

  let response_path = "data/ollama/response.json"

  let error_path = "data/ollama/error.json"
end

module T = Agent_test.Make (Agentlib.Ollama_agent.Make) (Paths)

let tests = T.tests
