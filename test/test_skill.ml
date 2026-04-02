open Agentlib

let skill_result_testable =
  Alcotest.result
    (Alcotest.testable Skill.pp_frontmatter Skill.equal_frontmatter)
    Alcotest.string

let loaded_skill_result_testable =
  Alcotest.result (Alcotest.testable Skill.pp Skill.equal) Alcotest.string

let with_temp_skill_file content f =
  let path = Filename.temp_file "skill_" ".md" in
  let oc = open_out_bin path in
  output_string oc content ;
  close_out oc ;
  Fun.protect (fun () -> f path) ~finally:(fun () -> Sys.remove path)

let frontmatter_from_temp_file content =
  with_temp_skill_file content (fun path ->
      Skill.load_from_file path
      |> Result.map (fun (skill : Skill.t) ->
          let {Skill.frontmatter; _} = skill in
          frontmatter ) )

let test_parse_minimal_frontmatter () =
  let content =
    {|---
      name: basic-skill
      description: A simple skill
      ---
      Body content|}
  in
  let actual = frontmatter_from_temp_file content in
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
  let actual = frontmatter_from_temp_file content in
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
  let actual = frontmatter_from_temp_file content in
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
  let actual = frontmatter_from_temp_file content in
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
  let actual = frontmatter_from_temp_file content in
  Alcotest.check skill_result_testable "missing description fails"
    (Error "Invalid SKILL.md: missing required frontmatter field 'description'.")
    actual

let test_load_from_file_success () =
  let content =
    {|---
      name: file-skill
      description: Loaded from file
      ---
      Body content|}
  in
  with_temp_skill_file content (fun path ->
      let actual = Skill.load_from_file path in
      let expected =
        Ok
          Skill.
            { frontmatter= {name= "file-skill"; description= "Loaded from file"}
            ; path }
      in
      Alcotest.(check loaded_skill_result_testable)
        "load_from_file parses frontmatter and keeps path" expected actual )

let test_load_from_file_invalid_frontmatter () =
  let content =
    {|---
      name: no-description
      ---
      Body content|}
  in
  with_temp_skill_file content (fun path ->
      let actual = Skill.load_from_file path in
      Alcotest.(check loaded_skill_result_testable)
        "load_from_file propagates frontmatter validation error"
        (Error
           "Invalid SKILL.md: missing required frontmatter field 'description'."
        ) actual )

let test_load_from_file_missing_file () =
  let path = Filename.temp_file "skill_missing_" ".md" in
  Sys.remove path ;
  let actual = Skill.load_from_file path in
  match actual with
  | Ok _ ->
      Alcotest.fail "expected load_from_file to fail for missing file"
  | Error msg ->
      Alcotest.(check bool)
        "missing file returns read error" true
        (String.starts_with ~prefix:"Cannot read skill file: " msg)

let tests =
  ( "skill"
  , [ Alcotest.test_case "parse minimal frontmatter" `Quick
        test_parse_minimal_frontmatter
    ; Alcotest.test_case "parse optional fields and metadata" `Quick
        test_parse_full_frontmatter
    ; Alcotest.test_case "missing frontmatter delimiters" `Quick
        test_missing_frontmatter_delimiters
    ; Alcotest.test_case "missing required fields" `Quick
        test_missing_description
    ; Alcotest.test_case "load from file success" `Quick
        test_load_from_file_success
    ; Alcotest.test_case "load from file invalid frontmatter" `Quick
        test_load_from_file_invalid_frontmatter
    ; Alcotest.test_case "load from file missing file" `Quick
        test_load_from_file_missing_file ] )
