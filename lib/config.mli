(** Ollama config section *)
type ollama = {url: string}

(** Type definition of the complete config file. *)
type t = {ollama: ollama}

val load : string option -> t
(** Load config from file path or default path if no path is given. *)
