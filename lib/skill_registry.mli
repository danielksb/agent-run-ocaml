type t

val empty : unit -> t

val register_skill : t -> string -> t
(** loads a skill from path and adds it into registry by skill name. invalid
    skill files are ignored. *)

val skills_to_instruction : t -> string
(** provides a short instruction to the LLM for using registered skills *)

val augment_prompt : original_prompt:string -> t -> string
(** prepends skill instruction when registry is non-empty *)
