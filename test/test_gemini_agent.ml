open Agent_run
open Gemini_agent

let response_data_path = "data/gemini/response.json"

let error_data_path = "data/gemini/error.json"

(** reads the entire file at path into a string *)
let read_file path =
  let file = open_in_bin path in
  let size = in_channel_length file in
  let data = really_input_string file size in
  close_in file ; data

let agent_response_testable =
  Alcotest.testable Agent.pp_agent_response Agent.equal_agent_response

let agent_error_testable =
  Alcotest.testable Agent.pp_agent_error Agent.equal_agent_error

let agent_result_testable =
  Alcotest.result agent_response_testable agent_error_testable

module MockHttpClient : Agent.HTTP_CLIENT = struct
  let post ~url:_ ~headers:_ ~body:_ =
    let mock_response = read_file response_data_path in
    Lwt.return (200, mock_response)
end

module MockHttpClientError : Agent.HTTP_CLIENT = struct
  let post ~url:_ ~headers:_ ~body:_ =
    let mock_response = read_file error_data_path in
    Lwt.return (401, mock_response)
end

module TestGeminiAgent = MakeGeminiAgent (MockHttpClient)

let test_request_success () =
  let agent = TestGeminiAgent.create_with_options "TEST_KEY" in
  let actual_response =
    TestGeminiAgent.send_request agent "Here is a prompt" |> Lwt_main.run
  in
  let expected_text =
    "In a peaceful grove beneath a silver moon, a unicorn named Lumina \
     discovered a hidden pool that reflected the stars. As she dipped her horn \
     into the water, the pool began to shimmer, revealing a pathway to a \
     magical realm of endless night skies. Filled with wonder, Lumina \
     whispered a wish for all who dream to find their own hidden magic, and as \
     she glanced back, her hoofprints sparkled like stardust."
  in
  let expected_response = Ok Agent.{response= expected_text} in
  Alcotest.(check agent_result_testable)
    "result must be successful" expected_response actual_response

let test_request_error () =
  let module TestGeminiAgentError = MakeGeminiAgent (MockHttpClientError) in
  let agent = TestGeminiAgentError.create_with_options "TEST_KEY" in
  let actual_response =
    TestGeminiAgentError.send_request agent "Here is a prompt" |> Lwt_main.run
  in
  let expected_text = "API key not valid. Please pass a valid API key." in
  let expected_response = Error Agent.{message= expected_text} in
  Alcotest.(check agent_result_testable)
    "result must be an error" expected_response actual_response

let tests =
  ( "gemini_agent"
  , [ Alcotest.test_case "parses successful response" `Quick test_request_success
    ; Alcotest.test_case "parses error response" `Quick test_request_error ] )
