type level = Normal | Verbose | Debug

let current_level = ref Normal

let set_level level = current_level := level

let set_verbose enabled =
  if enabled then set_level Verbose else set_level Normal

let set_debug enabled = if enabled then set_level Debug else set_level Normal

let is_verbose_enabled () =
  match !current_level with Verbose | Debug -> true | Normal -> false

let is_debug_enabled () = match !current_level with Debug -> true | _ -> false

let verbose msg =
  if is_verbose_enabled () then Printf.printf "INFO: %s\n%!" msg else ()

let debug msg =
  if is_debug_enabled () then Printf.eprintf "DEBUG: %s\n" msg else ()
