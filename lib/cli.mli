(** Platform side effects required by the CLI parser.
    This interface is injected to make CLI behavior testable. *)
module type PLATFORM = sig
  val argv : string array
  (** Raw process arguments, including executable name at index 0. *)

  val getenv_opt : string -> string option
  (** Read environment variable if present. *)

  val getcwd : unit -> string
  (** Current working directory for default tool context and relative paths. *)

  val file_exists : string -> bool
  (** Whether a path exists (file or directory). *)

  val is_regular_file : string -> bool
  (** Whether a path is a regular file. *)

  val stdin_read_all : unit -> string
  (** Read all bytes from stdin as one string. *)

  val file_read_all : string -> string
  (** Read full file content from disk as one string *)
end

(** Supported LLM vendors selected via CLI. *)
type vendor = OpenAi | Gemini | Ollama

(** Structured CLI-level messages. *)
type cli_msg =
  | Usage  (** Show usage text and exit without running an agent. *)
  | NoPrompt  (** No prompt provided via [--prompt]. *)
  | UnknownVendor of string  (** Unknown vendor name passed to [--vendor]. *)
  | NoApiKey of string  (** Required API key environment variable is missing. *)
  | LoadSkillFailed of string
      (** Loading one of the provided skill files failed. *)

(** Fully resolved runtime inputs used to construct an agent instance. *)
type runtime_parameters =
  {agent_config: Agent.config; vendor: vendor; prompt: string}

val cli_msg_to_string : cli_msg -> string
(** Render a CLI message as user-facing text. *)

(** CLI service interface. *)
module type S = sig
  val create_agent_config : unit -> (runtime_parameters, cli_msg) result
  (** Parse CLI inputs, load config/skills, resolve vendor credentials,
      and build final runtime parameters for the agent. *)
end

(** Build a CLI implementation from platform effects. *)
module Make : functor (Platform : PLATFORM) -> S
