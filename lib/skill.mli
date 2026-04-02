type frontmatter = {name: string; description: string} [@@deriving show, eq]

type t = {frontmatter: frontmatter; path: string} [@@deriving show, eq]

val skills_to_instruction : t list -> string
(** provides a short instruction to the LLM for using skills *)

val load_from_file : string -> (t, string) result
(** loads a skill from a given path *)
