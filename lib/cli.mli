module type PLATFORM = sig
  val argv : string array

  val getenv_opt : string -> string option

  val getcwd : unit -> string

  val file_exists : string -> bool

  val exit_with_error : unit -> 'a

  val is_regular_file : string -> bool

  val stdin_read_all : unit -> string

  val file_read_all : string -> string
end

module type S = sig
  val usage : unit -> unit

  val execute : unit -> unit
end

module Make : functor (Platform : PLATFORM) -> S
