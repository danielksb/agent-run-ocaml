open Agentlib

let agent_result_testable =
  let open Alcotest in
  result
    (testable Agent.pp_agent_response Agent.equal_agent_response)
    (testable Agent.pp_agent_error Agent.equal_agent_error)

(**
   Creates a collection of tests for a specific agent implementation.
*)
module Make
    (AgentMake : functor (Http : Http_client.S) -> Agent.AGENT)
    (TestConfig : Test_config.TEST_CONIFG) =
struct
  let test_request_success () =
    let mock_client =
      Http_mock.post_always_from_file ~response_status:200
        ~response_body_path:TestConfig.response_path
    in
    let module MockHttpClient = (val mock_client : Http_client.S) in
    let module TestAgent = AgentMake (MockHttpClient) in
    let agent = TestAgent.create TestConfig.agent_config in
    let actual_response =
      TestAgent.send_request agent "Here is a prompt" |> Lwt_main.run
    in
    let expected_text =
      "In a peaceful grove beneath a silver moon, a unicorn named Lumina \
       discovered a hidden pool that reflected the stars. As she dipped her \
       horn into the water, the pool began to shimmer, revealing a pathway to \
       a magical realm of endless night skies. Filled with wonder, Lumina \
       whispered a wish for all who dream to find their own hidden magic, and \
       as she glanced back, her hoofprints sparkled like stardust."
    in
    let expected_response = Ok Agent.{response= expected_text} in
    Alcotest.(check agent_result_testable)
      "result must be successful" expected_response actual_response

  let test_request_error () =
    let mock_client =
      Http_mock.post_always_from_file ~response_status:401
        ~response_body_path:TestConfig.error_path
    in
    let module MockHttpClientError = (val mock_client : Http_client.S) in
    let module TestAgentError = AgentMake (MockHttpClientError) in
    let agent = TestAgentError.create TestConfig.agent_config in
    let actual_response =
      TestAgentError.send_request agent "Here is a prompt" |> Lwt_main.run
    in
    let expected_text = "API key not valid. Please pass a valid API key." in
    let expected_response = Error Agent.{message= expected_text} in
    Alcotest.(check agent_result_testable)
      "result must be an error" expected_response actual_response

  let test_agent_loop () =
    let interactions =
      [ Http_mock.expect_post ~url:TestConfig.tool_url
          ~request_body_path:TestConfig.tool_call_request_path
          ~response_status:200
          ~response_body_path:TestConfig.tool_call_response_path
      ; Http_mock.expect_post ~url:TestConfig.tool_url
          ~request_body_path:TestConfig.tool_final_request_path
          ~response_status:200
          ~response_body_path:TestConfig.tool_final_response_path ]
    in
    let mock_client, assert_all_matched = Http_mock.make interactions in
    let module MockHttpClient = (val mock_client : Http_client.S) in
    let module TestAgentLoop = AgentMake (MockHttpClient) in
    let agent = TestAgentLoop.create TestConfig.agent_config in
    let result =
      TestAgentLoop.send_request agent
        "What is the current temperature in Berlin in Celsius?"
      |> Lwt_main.run
    in
    let expected =
      Ok Agent.{response= "The current temperature in Berlin is 22°C."}
    in
    Alcotest.(check agent_result_testable)
      "agent loop returns final response" expected result ;
    assert_all_matched ()

  let tests =
    ( TestConfig.suite_name
    , [ Alcotest.test_case "parses successful response" `Quick
          test_request_success
      ; Alcotest.test_case "parses error response" `Quick test_request_error
      ; Alcotest.test_case "agent loop with tool calling" `Quick test_agent_loop
      ] )
end
