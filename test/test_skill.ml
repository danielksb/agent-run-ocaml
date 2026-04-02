open Agentlib

let skill_result_testable =
  Alcotest.result
    (Alcotest.testable Skill.pp_frontmatter Skill.equal_frontmatter)
    Alcotest.string

let test_parse_minimal_frontmatter () =
  let content =
    {|---
      name: basic-skill
      description: A simple skill
      ---
      Body content|}
  in
  let actual = Skill.frontmatter_from_string content in
  let expected =
    Ok Skill.{name= "basic-skill"; description= "A simple skill"}
  in
  Alcotest.(check skill_result_testable)
    "minimal skill is parsed" expected actual

let test_parse_full_frontmatter () =
  let content =
    {|---
      name: full-skill
      description: Includes optional fields
      license: Apache-2.0
      compatibility: Requires git and network
      allowed-tools: Read Bash(git:*)
      metadata:
        author: example-org
        version: "1.0"
      ---
      Skill body|}
  in
  let actual = Skill.frontmatter_from_string content in
  let expected =
    Ok Skill.{name= "full-skill"; description= "Includes optional fields"}
  in
  Alcotest.check skill_result_testable "skill with full frontmatter is parsed"
    expected actual

let test_missing_frontmatter_delimiters () =
  let content =
    {|name: bad
      description: missing delimiter
      ---
      Body content|}
  in
  let actual = Skill.frontmatter_from_string content in
  Alcotest.check skill_result_testable "missing frontmatter start fails"
    (Error "Invalid SKILL.md: file must start with frontmatter delimiter '---'.")
    actual

let test_missing_name () =
  let content =
    {|---
      description: incomplete-skill
      ---
      Body content]
    |}
  in
  let actual = Skill.frontmatter_from_string content in
  Alcotest.check skill_result_testable "missing name fails"
    (Error "Invalid SKILL.md: missing required frontmatter field 'name'.")
    actual

let test_missing_description () =
  let content =
    {|---
      name: incomplete-skill
      ---
      Body content]
    |}
  in
  let actual = Skill.frontmatter_from_string content in
  Alcotest.check skill_result_testable "missing description fails"
    (Error "Invalid SKILL.md: missing required frontmatter field 'description'.")
    actual

let tests =
  ( "skill"
  , [ Alcotest.test_case "parse minimal frontmatter" `Quick
        test_parse_minimal_frontmatter
    ; Alcotest.test_case "parse optional fields and metadata" `Quick
        test_parse_full_frontmatter
    ; Alcotest.test_case "missing frontmatter delimiters" `Quick
        test_missing_frontmatter_delimiters
    ; Alcotest.test_case "missing required fields" `Quick
        test_missing_description ] )
