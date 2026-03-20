open Agent_run

(** reads the entire file at path into a string *)
let read_file path =
  let file = open_in_bin path in
  let size = in_channel_length file in
  let data = really_input_string file size in
  close_in file ; data

let agent_result_testable =
  let open Alcotest in
  result
    (testable Agent.pp_agent_response Agent.equal_agent_response)
    (testable Agent.pp_agent_error Agent.equal_agent_error)

module Make
    (M : functor (Http : Agent.HTTP_CLIENT) -> Agent.AGENT)
    (Paths : sig
      val suite_name : string
      (** name of the agent implementation *)

      val response_path : string
      (** path to file with successful HTTP response *)

      val error_path : string
      (** path to file with HTTP error response *)
    end) =
struct
  module MockHttpClient : Agent.HTTP_CLIENT = struct
    let post ~url:_ ~headers:_ ~body:_ =
      let mock_response = read_file Paths.response_path in
      Lwt.return (200, mock_response)
  end

  module MockHttpClientError : Agent.HTTP_CLIENT = struct
    let post ~url:_ ~headers:_ ~body:_ =
      let mock_response = read_file Paths.error_path in
      Lwt.return (401, mock_response)
  end

  module TestAgent = M (MockHttpClient)
  module TestAgentError = M (MockHttpClientError)

  let test_request_success () =
    let agent = TestAgent.create_with_options "TEST_KEY" in
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
    let agent = TestAgentError.create_with_options "TEST_KEY" in
    let actual_response =
      TestAgentError.send_request agent "Here is a prompt" |> Lwt_main.run
    in
    let expected_text = "API key not valid. Please pass a valid API key." in
    let expected_response = Error Agent.{message= expected_text} in
    Alcotest.(check agent_result_testable)
      "result must be an error" expected_response actual_response

  let tests =
    ( Paths.suite_name
    , [ Alcotest.test_case "parses successful response" `Quick
          test_request_success
      ; Alcotest.test_case "parses error response" `Quick test_request_error ]
    )
end
