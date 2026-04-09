module type PLATFORM = sig
  val argv : string array

  val getenv_opt : string -> string option

  val getcwd : unit -> string

  val file_exists : string -> bool

  val is_regular_file : string -> bool

  val stdin_read_all : unit -> string

  val file_read_all : string -> string
end

type vendor = OpenAi | Gemini | Ollama

type cli_msg =
  | Usage
  | NoPrompt
  | UnknownVendor of string
  | NoApiKey of string
  | LoadSkillFailed of string

type runtime_parameters =
  {agent_config: Agent.config; vendor: vendor; prompt: string}

val cli_msg_to_string : cli_msg -> string

module type S = sig
  val create_agent_config : unit -> (runtime_parameters, cli_msg) result
end

module Make : functor (Platform : PLATFORM) -> S
