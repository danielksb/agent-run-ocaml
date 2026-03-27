let () =
  Alcotest.run "Agent Run"
    [ Test_gemini_agent.tests
    ; Test_ollama_agent.tests
    ; Test_openai_agent.tests
    ; Test_tool.tests
    ; Test_tool_registry.tests
    ; Test_exec_program.tests ]
