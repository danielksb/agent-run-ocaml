open Agentlib

let skill_result_testable =
  let pp fmt (s : Skill.t) =
    Format.fprintf fmt "name=%s description=%s path=%s"
      (Option.value s.name ~default:"<none>")
      (Option.value s.description ~default:"<none>")
      s.skill_path
  in
  let eq (a : Skill.t) (b : Skill.t) =
    a.name = b.name
    && a.description = b.description
    && a.license = b.license
    && a.compatibility = b.compatibility
    && a.allowed_tools = b.allowed_tools
    && a.metadata = b.metadata
  in
  Alcotest.result (Alcotest.testable pp eq) Alcotest.string

let contains text pattern =
  let text_len = String.length text in
  let pattern_len = String.length pattern in
  let rec loop idx =
    if idx + pattern_len > text_len then false
    else if String.sub text idx pattern_len = pattern then true
    else loop (idx + 1)
  in
  if pattern_len = 0 then true else loop 0

let with_temp_skill content f =
  let path = Filename.temp_file "skill_test_" ".md" in
  let out = open_out path in
  Out_channel.output_string out content ;
  close_out out ;
  Fun.protect
    (fun () -> f path)
    ~finally:(fun () ->
      if Sys.file_exists path then Sys.remove path )

let test_parse_minimal_frontmatter () =
  let content =
    String.concat "\n"
      [ "---"
      ; "name: basic-skill"
      ; "description: A simple skill"
      ; "---"
      ; "Body content" ]
  in
  with_temp_skill content (fun path ->
      let result = Skill.from_file path in
      let expected =
        Ok
          Skill.
            { name= Some "basic-skill"
            ; description= Some "A simple skill"
            ; license= None
            ; compatibility= None
            ; metadata= []
            ; allowed_tools= None
            ; skill_path= path }
      in
      Alcotest.(check skill_result_testable) "minimal skill is parsed" expected
        result )

let test_parse_optional_fields_and_metadata () =
  let content =
    String.concat "\n"
      [ "---"
      ; "name: optional-skill"
      ; "description: Includes optional fields"
      ; "license: Apache-2.0"
      ; "compatibility: Requires git and network"
      ; "allowed-tools: Read Bash(git:*)"
      ; "metadata:"
      ; "  author: example-org"
      ; "  version: \"1.0\""
      ; "---"
      ; "Skill body" ]
  in
  with_temp_skill content (fun path ->
      match Skill.from_file path with
      | Error e ->
          Alcotest.fail ("expected parse success, got: " ^ e)
      | Ok parsed ->
          Alcotest.(check (option string))
            "license parsed" (Some "Apache-2.0")
            parsed.license ;
          Alcotest.(check (option string))
            "compatibility parsed" (Some "Requires git and network")
            parsed.compatibility ;
          Alcotest.(check (option string))
            "allowed-tools parsed" (Some "Read Bash(git:*)")
            parsed.allowed_tools ;
          Alcotest.(check (list (pair string string)))
            "metadata parsed"
            [("author", "example-org"); ("version", "1.0")]
            parsed.metadata )

let test_missing_frontmatter_delimiters () =
  let content =
    String.concat "\n"
      [ "name: bad"
      ; "description: missing delimiter"
      ; "---"
      ; "Body content" ]
  in
  with_temp_skill content (fun path ->
      let result = Skill.from_file path in
      Alcotest.(check skill_result_testable)
        "missing frontmatter start fails"
        (Error
           "Invalid SKILL.md: file must start with frontmatter delimiter '---'."
        )
        result )

let test_missing_required_fields () =
  let content =
    String.concat "\n"
      [ "---"
      ; "name: incomplete-skill"
      ; "---"
      ; "Body content" ]
  in
  with_temp_skill content (fun path ->
      let result = Skill.from_file path in
      Alcotest.(check skill_result_testable)
        "missing description fails"
        (Error
           "Invalid SKILL.md: missing required frontmatter field \
            'description'." )
        result )

let test_prompt_augmentation () =
  let skill =
    Skill.
      { name= Some "csv-analysis"
      ; description= Some "Analyze CSV files"
      ; license= None
      ; compatibility= None
      ; metadata= [("author", "example")]
      ; allowed_tools= None
      ; skill_path= "C:/skills/csv/SKILL.md" }
  in
  let original_prompt = "Please inspect this CSV." in
  let augmented = Skill.augment_prompt ~original_prompt ~skill in
  Alcotest.(check bool)
    "contains instruction to read full skill file" true
    (contains augmented "call read_file with the exact skill path") ;
  Alcotest.(check bool)
    "contains skill path" true
    (contains augmented "C:/skills/csv/SKILL.md") ;
  Alcotest.(check bool)
    "contains frontmatter name" true
    (contains augmented "name: csv-analysis") ;
  Alcotest.(check bool)
    "preserves original prompt" true
    (String.ends_with ~suffix:original_prompt augmented)

let test_prompt_augmentation_many_skills () =
  let skill1 =
    Skill.
      { name= Some "csv-analysis"
      ; description= Some "Analyze CSV files"
      ; license= None
      ; compatibility= None
      ; metadata= []
      ; allowed_tools= None
      ; skill_path= "C:/skills/csv/SKILL.md" }
  in
  let skill2 =
    Skill.
      { name= Some "pdf-processing"
      ; description= Some "Handle PDF files"
      ; license= None
      ; compatibility= None
      ; metadata= []
      ; allowed_tools= None
      ; skill_path= "C:/skills/pdf/SKILL.md" }
  in
  let original_prompt = "Process data sources." in
  let augmented =
    Skill.augment_prompt_many ~original_prompt ~skills:[skill1; skill2]
  in
  Alcotest.(check bool)
    "contains first skill" true (contains augmented "Skill 1:") ;
  Alcotest.(check bool)
    "contains second skill" true (contains augmented "Skill 2:") ;
  Alcotest.(check bool)
    "contains second skill path" true
    (contains augmented "C:/skills/pdf/SKILL.md") ;
  Alcotest.(check bool)
    "preserves original prompt" true
    (String.ends_with ~suffix:original_prompt augmented)

let tests =
  ( "skill"
  , [ Alcotest.test_case "parse minimal frontmatter" `Quick
        test_parse_minimal_frontmatter
    ; Alcotest.test_case "parse optional fields and metadata" `Quick
        test_parse_optional_fields_and_metadata
    ; Alcotest.test_case "missing frontmatter delimiters" `Quick
        test_missing_frontmatter_delimiters
    ; Alcotest.test_case "missing required fields" `Quick
        test_missing_required_fields
    ; Alcotest.test_case "prompt augmentation" `Quick
        test_prompt_augmentation
    ; Alcotest.test_case "prompt augmentation many skills" `Quick
        test_prompt_augmentation_many_skills ] )
