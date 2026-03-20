open Agent_run

module Paths = struct
  let suite_name = "gemini_agent"

  let response_path = "data/gemini/response.json"

  let error_path = "data/gemini/error.json"
end

module T = Agent_test.Make (Gemini_agent.MakeGeminiAgent) (Paths)

let tests = T.tests
