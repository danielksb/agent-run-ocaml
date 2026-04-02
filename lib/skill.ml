type frontmatter = {name: string; description: string} [@@deriving show, eq]

type t = {frontmatter: frontmatter; path: string} [@@deriving show, eq]

type frontmatter_parser_state = {name: string option; description: string option}

let validate_required_frontmatter frontmatter : (frontmatter, string) result =
  match frontmatter.name with
  | None ->
      Error "Invalid SKILL.md: missing required frontmatter field 'name'."
  | Some name -> (
    match frontmatter.description with
    | None ->
        Error
          "Invalid SKILL.md: missing required frontmatter field 'description'."
    | Some description ->
        Ok ({name; description} : frontmatter) )

let parse_field_line line frontmatter =
  match String.index_opt line ':' with
  | None ->
      frontmatter
  | Some idx -> (
      let key = String.sub line 0 idx |> String.trim in
      let value =
        String.sub line (idx + 1) (String.length line - idx - 1) |> String.trim
      in
      match key with
      | "name" ->
          {frontmatter with name= Some value}
      | "description" ->
          {frontmatter with description= Some value}
      | _ ->
          frontmatter )

let rec parse_frontmatter lines frontmatter =
  match lines with
  | [] ->
      Error "Invalid SKILL.md: missing closing frontmatter delimiter '---'."
  | line :: rest when line = "---" ->
      validate_required_frontmatter frontmatter
  | line :: rest ->
      parse_frontmatter rest (parse_field_line line frontmatter)

let frontmatter_from_string content =
  let lines = content |> String.split_on_char '\n' |> List.map String.trim in
  match lines with
  | first :: rest when first = "---" ->
      parse_frontmatter rest {name= None; description= None}
  | _ ->
      Error
        "Invalid SKILL.md: file must start with frontmatter delimiter '---'."

let frontmatter_block (skill : t) =
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

let skills_to_instruction skills =
  if List.is_empty skills then "" else build_instruction skills

let load_from_file path =
  try
    let content = In_channel.with_open_bin path In_channel.input_all in
    match frontmatter_from_string content with
    | Error err ->
        Error err
    | Ok frontmatter ->
        Ok {frontmatter; path}
  with Sys_error msg -> Error ("Cannot read skill file: " ^ msg)
