open Agentlib

let string_result_testable = Alcotest.(result string string)

let with_temp_file content f =
  let path = Filename.temp_file "fetch_url_response_" ".txt" in
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out ;
  Fun.protect
    (fun () -> f path)
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)

let test_fetch_url_uses_http_mock () =
  with_temp_file "mock body from test server" (fun response_body_path ->
      let expectations =
        [ Http_mock.expect_get ~url:"https://example.com/test"
            ~response_status:200 ~response_body_path ]
      in
      let mock_client, assert_all_matched = Http_mock.make expectations in
      let module Http = (val mock_client : Http_client.S) in
      let module FetchUrl = Fetch_url.Make (Http) in
      let result =
        Lwt_main.run
          (FetchUrl.run (`Assoc [("url", `String "https://example.com/test")]))
      in
      Alcotest.(check string_result_testable)
        "response body is returned from mock" (Ok "mock body from test server")
        result ;
      assert_all_matched () )

let tests =
  ( "fetch_url"
  , [ Alcotest.test_case "fetches url via http mock" `Quick
        test_fetch_url_uses_http_mock ] )
