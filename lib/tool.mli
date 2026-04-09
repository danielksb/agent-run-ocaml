(** Execution context passed to every tool invocation. *)
type tool_context = {working_directory: string}

(** Tool implementation function.
    It receives the execution context and raw JSON arguments, and returns either
    a success payload or an error message. *)
type handler = tool_context -> Yojson.Safe.t -> (string, string) result Lwt.t

(** String-keyed map used for JSON object-like schemas. *)
module StringMap : Map.S with type key = string

(** Type alias so [@@deriving yojson] can find the converters. *)
type 'a string_map = 'a StringMap.t

val string_map_to_yojson :
  ('a -> Yojson.Safe.t) -> 'a string_map -> Yojson.Safe.t
(** Convert a string map to a JSON object using the provided value encoder. *)

val string_map_of_yojson :
     (Yojson.Safe.t -> ('a, string) result)
  -> Yojson.Safe.t
  -> ('a string_map, string) result
(** Parse a JSON object into a string map using the provided value decoder. *)

(** JSON Schema-like property description used by tool parameter schemas. *)
type property =
  { type_: string [@key "type"]
  ; description: string option [@default None]
  ; enum: string list option [@default None]
  ; items: property option [@default None] }
[@@deriving yojson]

(** Top-level parameter schema for a tool. *)
type parameters =
  { type_: string [@key "type"]
  ; properties: property string_map
  ; required: string list }
[@@deriving yojson]

(** Tool definition exposed to model-facing clients. *)
type t =
  { type_: string [@key "type"]
  ; name: string
  ; description: string
  ; parameters: parameters
  ; strict: bool }
[@@deriving yojson]

val validate_arguments : t -> Yojson.Safe.t -> (Yojson.Safe.t, string) result
(** Validate tool-call arguments against required parameter names.
    Returns the original JSON object on success. *)
