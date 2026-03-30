type t =
  { name: string option
  ; description: string option
  ; license: string option
  ; compatibility: string option
  ; metadata: (string * string) list
  ; allowed_tools: string option
  ; skill_path: string }

let normalize_line line =
  if String.length line > 0 && line.[String.length line - 1] = '\r' then
    String.sub line 0 (String.length line - 1)
  else line

let split_lines content =
  String.split_on_char '\n' content |> List.map normalize_line

let split_key_value line =
  match String.index_opt line ':' with
  | None ->
      None
  | Some idx ->
      let key = String.sub line 0 idx |> String.trim in
      let value =
        String.sub line (idx + 1) (String.length line - idx - 1) |> String.trim
      in
      Some (key, value)

let strip_quotes value =
  let len = String.length value in
  if len >= 2 then
    let first = value.[0] in
    let last = value.[len - 1] in
    if (first = '"' && last = '"') || (first = '\'' && last = '\'') then
      String.sub value 1 (len - 2)
    else value
  else value

let parse_frontmatter_lines skill_path lines =
  let rec loop acc in_metadata remaining =
    match remaining with
    | [] ->
        if in_metadata then Ok {acc with metadata= List.rev acc.metadata}
        else Ok acc
    | line :: tl -> (
        let trimmed = String.trim line in
        if trimmed = "" then loop acc in_metadata tl
        else if
          in_metadata
          && ( String.starts_with ~prefix:" " line
             || String.starts_with ~prefix:"\t" line )
        then
          let entry = String.trim line in
          match split_key_value entry with
          | Some (k, v) when k <> "" ->
              loop
                {acc with metadata= (k, strip_quotes v) :: acc.metadata}
                true tl
          | _ ->
              Error
                "Invalid metadata entry in skill frontmatter. Expected 'key: \
                 value'."
        else
          let acc =
            if in_metadata then {acc with metadata= List.rev acc.metadata}
            else acc
          in
          match split_key_value line with
          | None ->
              Error
                ( "Invalid frontmatter line: " ^ line
                ^ ". Expected 'key: value'." )
          | Some ("metadata", "") ->
              loop acc true tl
          | Some ("name", value) ->
              loop {acc with name= Some (strip_quotes value)} false tl
          | Some ("description", value) ->
              loop {acc with description= Some (strip_quotes value)} false tl
          | Some ("license", value) ->
              loop {acc with license= Some (strip_quotes value)} false tl
          | Some ("compatibility", value) ->
              loop {acc with compatibility= Some (strip_quotes value)} false tl
          | Some ("allowed-tools", value) ->
              loop {acc with allowed_tools= Some (strip_quotes value)} false tl
          | Some (_unknown, _value) ->
              loop acc false tl )
  in
  loop
    { name= None
    ; description= None
    ; license= None
    ; compatibility= None
    ; metadata= []
    ; allowed_tools= None
    ; skill_path }
    false lines

let extract_frontmatter lines =
  match lines with
  | first :: rest when String.trim first = "---" ->
      let rec take_frontmatter acc remaining =
        match remaining with
        | [] ->
            Error
              "Invalid SKILL.md: missing closing frontmatter delimiter '---'."
        | line :: tl ->
            if String.trim line = "---" then Ok (List.rev acc, tl)
            else take_frontmatter (line :: acc) tl
      in
      take_frontmatter [] rest
  | _ ->
      Error
        "Invalid SKILL.md: file must start with frontmatter delimiter '---'."

let validate_required_fields (skill : t) =
  let required field_name value =
    match value with
    | Some s when String.trim s <> "" ->
        Ok ()
    | _ ->
        Error
          ( "Invalid SKILL.md: missing required frontmatter field '"
          ^ field_name ^ "'." )
  in
  Result.bind (required "name" skill.name) (fun () ->
      required "description" skill.description |> Result.map (fun () -> skill) )

let from_file skill_path =
  try
    let content = In_channel.with_open_bin skill_path In_channel.input_all in
    let lines = split_lines content in
    Result.bind (extract_frontmatter lines) (fun (frontmatter, _body) ->
        Result.bind
          (parse_frontmatter_lines skill_path frontmatter)
          validate_required_fields )
  with Sys_error msg -> Error ("Cannot read skill file: " ^ msg)

let metadata_lines metadata =
  metadata |> List.map (fun (k, v) -> "- " ^ k ^ ": " ^ v) |> String.concat "\n"

let optional_line label = function
  | Some v when String.trim v <> "" ->
      label ^ ": " ^ v
  | _ ->
      label ^ ": <none>"

let frontmatter_block (skill : t) =
  let metadata_block =
    match skill.metadata with
    | [] ->
        "metadata:\n- <none>"
    | entries ->
        "metadata:\n" ^ metadata_lines entries
  in
  String.concat "\n"
    [ "skill-path: " ^ skill.skill_path
    ; optional_line "name" skill.name
    ; optional_line "description" skill.description
    ; optional_line "license" skill.license
    ; optional_line "compatibility" skill.compatibility
    ; optional_line "allowed-tools" skill.allowed_tools
    ; metadata_block ]

let augment_prompt_many ~original_prompt ~skills =
  let blocks =
    skills
    |> List.mapi (fun i skill ->
        String.concat "\n"
          [Printf.sprintf "Skill %d:" (i + 1); frontmatter_block skill] )
    |> String.concat "\n\n"
  in
  String.concat "\n"
    [ "Skills are available for this request."
    ; "Use skill frontmatter to decide whether a skill is relevant."
    ; "When details are needed, call read_file with the exact skill path."
    ; ""
    ; "Available skill frontmatter:"
    ; blocks
    ; ""
    ; "User prompt:"
    ; original_prompt ]

let augment_prompt ~original_prompt ~skill =
  augment_prompt_many ~original_prompt ~skills:[skill]
