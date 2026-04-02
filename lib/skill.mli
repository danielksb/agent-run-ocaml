type frontmatter = {name: string; description: string} [@@deriving show, eq]

val frontmatter_from_string : string -> (frontmatter, string) result
(** loads and validates frontmatter from markdown *)

val frontmatters_to_instruction : frontmatter list -> string
(** provides a short instruction to the LLM for using skills *)
