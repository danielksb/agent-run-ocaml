type t =
  { name: string option
  ; description: string option
  ; license: string option
  ; compatibility: string option
  ; metadata: (string * string) list
  ; allowed_tools: string option
  ; skill_path: string }

val from_file : string -> (t, string) result

val augment_prompt : original_prompt:string -> skill:t -> string

val augment_prompt_many : original_prompt:string -> skills:t list -> string
