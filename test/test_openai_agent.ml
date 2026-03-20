open Agent_run
open Openai_agent

let response_data_path = "data/openai/response.json"

let error_data_path = "data/openai/error.json"

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

module TestOpenAiAgent = MakeOpenAiAgent (MockHttpClient)

let test_request_success () =
  let agent = TestOpenAiAgent.create_with_options "TEST_KEY" in
  let actual_response =
    TestOpenAiAgent.send_request agent "Here is a prompt" |> Lwt_main.run
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
  let module TestOpenAiAgentError = MakeOpenAiAgent (MockHttpClientError) in
  let agent = TestOpenAiAgentError.create_with_options "TEST_KEY" in
  let actual_response =
    TestOpenAiAgentError.send_request agent "Here is a prompt" |> Lwt_main.run
  in
  let expected_text =
    "Incorrect API key provided: TEST. You can find your API key at \
     https://platform.openai.com/account/api-keys."
  in
  let expected_response = Error Agent.{message= expected_text} in
  Alcotest.(check agent_result_testable)
    "result must be an error" expected_response actual_response

let () =
  Alcotest.run "Agent Run"
    [ ( "openai_agent"
      , [ Alcotest.test_case "parses successful response" `Quick
            test_request_success
        ; Alcotest.test_case "parses error response" `Quick test_request_error
        ] ) ]
