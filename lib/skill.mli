type frontmatter = {name: string; description: string} [@@deriving show, eq]

type t = {frontmatter: frontmatter; path: string} [@@deriving show, eq]

val load_from_file : string -> (t, string) result
(** loads a skill from a given path *)
