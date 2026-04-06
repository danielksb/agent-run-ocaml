(** Common runtime configuration for concrete agent implementations. *)
type config =
  { model_name: string
  ; api_key: string
  ; base_url: string
  ; tool_context: Tool_registry.tool_context }

(** Successful final response returned by an agent. *)
type agent_response = {response: string} [@@deriving show, eq]

(** Error returned by an agent when a request cannot complete. *)
type agent_error = {message: string} [@@deriving show, eq]

(** Result type used by all agent request entry points. *)
type agent_result = (agent_response, agent_error) result

(** Runtime interface for a configured agent instance. *)
module type AGENT = sig
  (** Opaque agent handle created from runtime configuration. *)
  type t

  val create : config -> t
  (** Build an agent instance from the given configuration. *)

  val send_request : t -> string -> agent_result Lwt.t
  (** Send a user prompt and resolve to either a final response or an error. *)
end

(** Structured tool call emitted by the model. *)
type tool_call = {name: string; arguments: Yojson.Safe.t; id: string option}

(** Structured tool execution result fed back to the model. *)
type tool_result = {name: string; content: string; id: string option}

(** Parsed model response categories used by the generic request loop. *)
type parsed_response =
  | TextResponse of string
  | ToolCallResponse of {content: string; tool_calls: tool_call list}
  | ErrorResponse of string

(** Vendor adapter contract used by [Make]. *)
module type VENDOR = sig
  (** Vendor-specific message representation sent to the model API. *)
  type msg

  val user_message : string -> msg
  (** Convert a user prompt into the vendor-specific user request message. *)

  val assistant_message : string -> tool_call list -> msg
  (** Build one assistant message that carries model text and tool calls. *)

  val tool_message : tool_result -> msg
  (** Build one tool-result message that will be sent back to the model. *)

  val request_headers : config -> (string * string) list
  (** Build HTTP headers for this vendor using the runtime configuration. *)

  val request_url : config -> string
  (** Build the vendor endpoint URL for the current configuration. *)

  val request_body : config -> Tool.t list -> msg list -> string
  (** Serialize a vendor request body from config, tool declarations and chat messages. *)

  val parse_response : string -> parsed_response
  (** Parse a raw HTTP response body into a normalized response category. *)
end

(** Build a concrete [AGENT] implementation from a vendor adapter, HTTP client and tool provider. *)
module Make : functor
  (Vendor : VENDOR)
  (Http : Http_client.S)
  (Tools : Tool_registry.PROVIDER)
  -> AGENT
