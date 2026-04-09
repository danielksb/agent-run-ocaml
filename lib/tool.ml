type tool_context = {working_directory: string}

type handler = tool_context -> Yojson.Safe.t -> (string, string) result Lwt.t

module StringMap = Map.Make (String)

(** Type alias so [@@deriving yojson] can find the converters. *)
type 'a string_map = 'a StringMap.t

let string_map_to_yojson value_to_yojson m =
  `Assoc (StringMap.fold (fun k v acc -> (k, value_to_yojson v) :: acc) m [])

let string_map_of_yojson value_of_yojson = function
  | `Assoc pairs ->
      List.fold_left
        (fun acc (k, v) ->
          match (acc, value_of_yojson v) with
          | Ok m, Ok value ->
              Ok (StringMap.add k value m)
          | (Error _ as e), _ ->
              e
          | _, Error e ->
              Error e )
        (Ok StringMap.empty) pairs
  | _ ->
      Error "expected JSON object for string_map"

type property =
  { type_: string [@key "type"]
  ; description: string option [@default None]
  ; enum: string list option [@default None]
  ; items: property option [@default None] }
[@@deriving yojson]

type parameters =
  { type_: string [@key "type"]
  ; properties: property string_map
  ; required: string list }
[@@deriving yojson]

type t =
  { type_: string [@key "type"]
  ; name: string
  ; description: string
  ; parameters: parameters
  ; strict: bool }
[@@deriving yojson]

let validate_arguments (tool : t) args =
  match args with
  | `Assoc fields -> (
      let missing =
        List.find_opt
          (fun req ->
            match List.assoc_opt req fields with
            | None | Some `Null ->
                true
            | _ ->
                false )
          tool.parameters.required
      in
      match missing with
      | Some name ->
          Error ("missing required argument: " ^ name)
      | None ->
          Ok args )
  | _ ->
      Error "arguments must be a JSON object"
