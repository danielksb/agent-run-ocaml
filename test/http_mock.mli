open Agentlib

type http_method

type interaction

val expect_post :
     url:string
  -> request_body_path:string
  -> response_status:int
  -> response_body_path:string
  -> interaction

val expect_get :
  url:string -> response_status:int -> response_body_path:string -> interaction

val make : interaction list -> (module Agent.HTTP_CLIENT) * (unit -> unit)
(**
  Creates a strict mock HTTP client.
  Each expected interaction can be used at most once.
*)

val post_always_from_file :
  response_status:int -> response_body_path:string -> (module Agent.HTTP_CLIENT)
