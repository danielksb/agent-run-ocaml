open Agentlib

type http_method = [`GET | `POST | `PUT | `PATCH | `DELETE]

type interaction =
  { method_: http_method
  ; url: string
  ; request_body: string option
  ; response_status: int
  ; response_body: string }

let read_file path =
  let file = open_in_bin path in
  let size = in_channel_length file in
  let data = really_input_string file size in
  close_in file ; data

let expect_post ~url ~request_body_path ~response_status ~response_body_path =
  let request_body = Some (read_file request_body_path) in
  let response_body = read_file response_body_path in
  {method_= `POST; url; request_body; response_status; response_body}

let post_always_from_file ~response_status ~response_body_path =
  let response_body = read_file response_body_path in
  let module Client : Agent.HTTP_CLIENT = struct
    let post ~url:_ ~headers:_ ~body:_ =
      Lwt.return (response_status, response_body)
  end in
  (module Client : Agent.HTTP_CLIENT)

let pp_method (m : http_method) =
  match m with
  | `GET ->
      "GET"
  | `POST ->
      "POST"
  | `PUT ->
      "PUT"
  | `PATCH ->
      "PATCH"
  | `DELETE ->
      "DELETE"

let json_pretty (s : string) : string =
  (* If the payload is JSON, normalize it into pretty-printed form so that
     fixtures can remain human-readable while matching stays strict. *)
  let j = Yojson.Safe.from_string s in
  (* [pretty_to_string] is available in yojson; if it changes in the future,
     tests will fail compilation and we can adapt. *)
  Yojson.Safe.pretty_to_string j

let json_equal (a : string) (b : string) =
  try json_pretty a = json_pretty b with _ -> a = b

type state = {mutable remaining: interaction list}

let same_expectation (a : interaction) (b : interaction) =
  a.method_ = b.method_ && a.url = b.url
  && a.request_body = b.request_body
  && a.response_status = b.response_status
  && a.response_body = b.response_body

let remove_first (target : interaction) (lst : interaction list) =
  let rec aux acc = function
    | [] ->
        List.rev acc
    | x :: xs ->
        if same_expectation x target then List.rev_append acc xs
        else aux (x :: acc) xs
  in
  aux [] lst

let make expectations =
  let state = {remaining= expectations} in
  let failf fmt = Printf.ksprintf failwith fmt in
  let assert_all_matched () =
    match state.remaining with
    | [] ->
        ()
    | remaining ->
        let rem_desc =
          remaining
          |> List.map (fun e ->
              Printf.sprintf "%s %s" (pp_method e.method_) e.url )
          |> String.concat ", "
        in
        failf "HTTP mock: expected interactions not used: %s" rem_desc
  in
  let post_impl ~url ~headers:_ ~body =
    let actual_method = `POST in
    let match_index =
      List.find_opt
        (fun e -> e.url = url && e.method_ = actual_method)
        state.remaining
    in
    match match_index with
    | Some e -> (
      match e.request_body with
      | None ->
          (* No strict request body matching. *)
          state.remaining <- remove_first e state.remaining ;
          Lwt.return (e.response_status, e.response_body)
      | Some expected_body ->
          if json_equal expected_body body then (
            state.remaining <- remove_first e state.remaining ;
            Lwt.return (e.response_status, e.response_body) )
          else
            failf
              "HTTP mock: request body mismatch for %s %s.\n\
               Expected: %s\n\
               Actual:   %s"
              (pp_method e.method_) e.url expected_body body )
    | None ->
        (* Check for method mismatch with correct URL. *)
        let url_only = List.filter (fun e -> e.url = url) state.remaining in
        if url_only <> [] then
          let expected_methods =
            url_only
            |> List.map (fun e -> pp_method e.method_)
            |> List.sort_uniq String.compare
            |> String.concat ", "
          in
          failf
            "HTTP mock: method mismatch for URL %s. Expected method(s): %s, \
             actual: %s"
            url expected_methods (pp_method actual_method)
        else
          let rem_urls =
            state.remaining
            |> List.map (fun e ->
                Printf.sprintf "%s (%s)" e.url (pp_method e.method_) )
            |> String.concat ", "
          in
          failf
            "HTTP mock: unexpected request %s %s. Remaining expectations: %s"
            (pp_method actual_method) url rem_urls
  in
  let module Client : Agent.HTTP_CLIENT = struct
    let post ~url ~headers ~body = post_impl ~url ~headers ~body
  end in
  ((module Client : Agent.HTTP_CLIENT), assert_all_matched)
