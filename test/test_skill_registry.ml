open Agentlib

let contains text pattern =
  let text_len = String.length text in
  let pattern_len = String.length pattern in
  let rec loop i =
    if i + pattern_len > text_len then false
    else if String.sub text i pattern_len = pattern then true
    else loop (i + 1)
  in
  if pattern_len = 0 then true else loop 0

let with_temp_skill_file content f =
  let path = Filename.temp_file "skill_registry_" ".md" in
  let oc = open_out_bin path in
  output_string oc content ;
  close_out oc ;
  Fun.protect (fun () -> f path) ~finally:(fun () -> Sys.remove path)

let test_register_skill_adds_valid_skill () =
  let content =
    {|---
      name: csv-skill
      description: Parses CSV files
      ---
      Body|}
  in
  with_temp_skill_file content (fun path ->
      let registry =
        Skill_registry.register_skill (Skill_registry.empty ()) path
      in
      let instruction = Skill_registry.skills_to_instruction registry in
      Alcotest.(check bool)
        "name is present" true
        (contains instruction "name: csv-skill") ;
      Alcotest.(check bool)
        "description is present" true
        (contains instruction "description: Parses CSV files") ;
      Alcotest.(check bool)
        "path is present" true
        (contains instruction ("location: " ^ path)) )

let test_register_skill_invalid_frontmatter_is_ignored () =
  let content = {|---
      name: broken-skill
      ---
      Body|} in
  with_temp_skill_file content (fun path ->
      let registry =
        Skill_registry.register_skill (Skill_registry.empty ()) path
      in
      Alcotest.(check string)
        "invalid skill does not change empty registry" ""
        (Skill_registry.skills_to_instruction registry) )

let test_register_skill_same_name_overrides_previous () =
  let first_content =
    {|---
      name: duplicate
      description: first
      ---
      Body|}
  in
  let second_content =
    {|---
      name: duplicate
      description: second
      ---
      Body|}
  in
  with_temp_skill_file first_content (fun first_path ->
      with_temp_skill_file second_content (fun second_path ->
          let registry =
            Skill_registry.empty ()
            |> fun r ->
            Skill_registry.register_skill r first_path
            |> fun r -> Skill_registry.register_skill r second_path
          in
          let instruction = Skill_registry.skills_to_instruction registry in
          Alcotest.(check bool)
            "new description is present" true
            (contains instruction "description: second") ;
          Alcotest.(check bool)
            "old description is not present" false
            (contains instruction "description: first") ;
          Alcotest.(check bool)
            "new path is present" true
            (contains instruction ("location: " ^ second_path)) ;
          Alcotest.(check bool)
            "old path is not present" false
            (contains instruction ("location: " ^ first_path)) ) )

let test_augment_prompt_empty_registry_returns_original () =
  let original_prompt = "Investigate this issue." in
  let actual =
    Skill_registry.augment_prompt ~original_prompt (Skill_registry.empty ())
  in
  Alcotest.(check string)
    "empty registry keeps prompt unchanged" original_prompt actual

let test_augment_prompt_includes_registered_skills_and_user_prompt () =
  let content =
    {|---
      name: prompt-skill
      description: helps with prompts
      ---
      Body|}
  in
  with_temp_skill_file content (fun path ->
      let registry =
        Skill_registry.register_skill (Skill_registry.empty ()) path
      in
      let original_prompt = "How do I parse this file?" in
      let actual = Skill_registry.augment_prompt ~original_prompt registry in
      Alcotest.(check bool)
        "contains heading" true
        (contains actual
           "The following skills provide specialized instructions for specific \
            tasks." ) ;
      Alcotest.(check bool)
        "contains skill path" true
        (contains actual ("location: " ^ path)) ;
      Alcotest.(check bool)
        "contains user prompt separator" true
        (contains actual "User prompt:") ;
      Alcotest.(check bool)
        "ends with original prompt" true
        (String.ends_with ~suffix:original_prompt actual) )

let tests =
  ( "skill_registry"
  , [ Alcotest.test_case "registers valid skill" `Quick
        test_register_skill_adds_valid_skill
    ; Alcotest.test_case "ignores invalid skill" `Quick
        test_register_skill_invalid_frontmatter_is_ignored
    ; Alcotest.test_case "overrides duplicate skill name" `Quick
        test_register_skill_same_name_overrides_previous
    ; Alcotest.test_case "augment prompt empty registry" `Quick
        test_augment_prompt_empty_registry_returns_original
    ; Alcotest.test_case "augment prompt includes skills" `Quick
        test_augment_prompt_includes_registered_skills_and_user_prompt ] )
