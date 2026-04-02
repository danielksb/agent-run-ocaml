module StringMap = Map.Make (String)

type t = {skills: Skill.t StringMap.t}

let empty () = {skills= StringMap.empty}

let register_skill registry path =
  match Skill.load_from_file path with
  | Ok skill ->
      let name = skill.frontmatter.name in
      Logging.verbose (Printf.sprintf "loaded skill \"%s\"" name) ;
      {skills= StringMap.add name skill registry.skills}
  | Error err ->
      Printf.eprintf "ERROR: cannot load skill %s\n" err ;
      registry

let frontmatter_block (skill : Skill.t) =
  String.concat "\n"
    [ "name: " ^ skill.frontmatter.name
    ; "description: " ^ skill.frontmatter.description
    ; "path: " ^ skill.path ]

let build_instruction skills =
  String.concat "\n"
    [ "Skills are available for this request."
    ; "Use skill frontmatter to decide whether a skill is relevant."
    ; "When details are needed, call read_file with the exact skill path."
    ; ""
    ; "Available skill frontmatter:"
    ; skills |> List.map frontmatter_block |> String.concat "\n"
    ; "\n" ]

let skills_to_instruction registry =
  if StringMap.is_empty registry.skills then String.empty
  else build_instruction (registry.skills |> StringMap.to_list |> List.map snd)

let augment_prompt ~original_prompt registry =
  let instruction = skills_to_instruction registry in
  if String.length instruction = 0 then original_prompt
  else String.concat "\n" [instruction; "User prompt:"; original_prompt]
