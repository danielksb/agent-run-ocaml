let () =
  Alcotest.run "Agent Run" [Test_gemini_agent.tests; Test_openai_agent.tests]
