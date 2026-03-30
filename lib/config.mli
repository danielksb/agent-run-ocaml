(** Shared vendor config section. *)
type vendor = {model: string option}

(** Ollama config section *)
type ollama =
  { url: string
  ; model: string option }

(** Type definition of the complete config file. *)
type t =
  { openai: vendor
  ; gemini: vendor
  ; ollama: ollama }

val load : string option -> t
(** Load config from file path or default path if no path is given. *)
