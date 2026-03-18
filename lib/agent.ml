type agent_response = {response: string}

type agent_error = {message: string}

module type AGENT = sig
  type t

  val create : unit -> t

  val send_request : t -> string -> (agent_response, agent_error) result Lwt.t
end
