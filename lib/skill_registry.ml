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
    ; "location: " ^ skill.path ]

let build_instruction skills =
  String.concat "\n"
    [ {|The following skills provide specialized instructions for specific tasks.
        When a task matches a skill's description, use your read_file tool to load
        the file at the listed location before proceeding.|}
    ; ""
    ; "Available skills:"
    ; skills |> List.map frontmatter_block |> String.concat "\n\n"
    ; "\n" ]

let skills_to_instruction registry =
  if StringMap.is_empty registry.skills then String.empty
  else build_instruction (registry.skills |> StringMap.to_list |> List.map snd)

let augment_prompt ~original_prompt registry =
  let instruction = skills_to_instruction registry in
  if String.length instruction = 0 then original_prompt
  else String.concat "\n" [instruction; "User prompt:"; original_prompt]
