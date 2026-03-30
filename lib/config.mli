(** Shared vendor config section. *)
type vendor = {model: string; base_url: string}

(** Type definition of the complete config file. *)
type t = {openai: vendor; gemini: vendor; ollama: vendor}

val load : string option -> t
(** Load config from file path or default path if no path is given. *)
