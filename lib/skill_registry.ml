module StringMap = Map.Make (String)

type t = {skills: Skill.t StringMap.t}

let empty () = {skills= StringMap.empty}
