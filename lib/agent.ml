type agent_response = {response: string} [@@deriving show, eq]

type agent_error = {message: string} [@@deriving show, eq]

type agent_result = (agent_response, agent_error) result

module type HTTP_CLIENT = sig
  val post :
       url:string
    -> headers:(string * string) list
    -> body:string
    -> (int * string) Lwt.t
end

module RealHttpClient : HTTP_CLIENT = struct
  open Lwt

  let post ~url ~headers ~body =
    let cohttp_headers = Cohttp.Header.of_list headers in
    let cohttp_body = Cohttp_lwt.Body.of_string body in
    Cohttp_lwt_unix.Client.post ~body:cohttp_body ~headers:cohttp_headers
      (Uri.of_string url)
    >>= fun (resp, body) ->
    let code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
    body |> Cohttp_lwt.Body.to_string >|= fun body_str -> (code, body_str)
end

module type AGENT = sig
  type t

  val create_with_options : string -> t

  val create : unit -> (t, agent_error) result

  val send_request : t -> string -> agent_result Lwt.t
end
