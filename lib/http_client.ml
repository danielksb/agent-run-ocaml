module type S = sig
  val get : url:string -> headers:(string * string) list -> (int * string) Lwt.t

  val post :
       url:string
    -> headers:(string * string) list
    -> body:string
    -> (int * string) Lwt.t
end

module Default : S = struct
  open Lwt

  let get ~url ~headers =
    let cohttp_headers = Cohttp.Header.of_list headers in
    Cohttp_lwt_unix.Client.get ~headers:cohttp_headers (Uri.of_string url)
    >>= fun (resp, body) ->
    let code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
    body |> Cohttp_lwt.Body.to_string
    >|= fun body_str ->
    Logging.debug ("Response code: " ^ Int.to_string code) ;
    Logging.debug ("Response body: " ^ body_str) ;
    (code, body_str)

  let post ~url ~headers ~body =
    Logging.debug ("Request body: " ^ body) ;
    let cohttp_headers = Cohttp.Header.of_list headers in
    let cohttp_body = Cohttp_lwt.Body.of_string body in
    Cohttp_lwt_unix.Client.post ~body:cohttp_body ~headers:cohttp_headers
      (Uri.of_string url)
    >>= fun (resp, body) ->
    let code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
    body |> Cohttp_lwt.Body.to_string
    >|= fun body_str ->
    Logging.debug ("Response code: " ^ Int.to_string code) ;
    Logging.debug ("Response body: " ^ body_str) ;
    (code, body_str)
end
