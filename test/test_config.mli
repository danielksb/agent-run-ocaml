module type TEST_CONIFG = sig
  val suite_name : string
  (** name of the agent implementation *)

  val create_with_options_arg : string
  (** Argument passed to [create_with_options] for this agent. *)

  val response_path : string
  (** path to file with successful HTTP response *)

  val error_path : string
  (** path to file with HTTP error response *)

  val tool_url : string
  (** URL used for the tool-calling flow (initial + follow-up calls). *)

  val tool_call_response_path : string
  (** path to file with tool-call HTTP response *)

  val tool_call_request_path : string
  (** path to file with tool-call HTTP request body *)

  val tool_final_response_path : string
  (** path to file with final text HTTP response after tool execution *)

  val tool_final_request_path : string
  (** path to file with final text HTTP request body *)
end
