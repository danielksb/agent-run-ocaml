let debug_enabled = ref false

let set_debug enabled = debug_enabled := enabled

let is_debug_enabled () = !debug_enabled

let debug msg =
  if is_debug_enabled () then Printf.eprintf "DEBUG: %s\n" msg else ()
