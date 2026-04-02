type handler = Yojson.Safe.t -> (string, string) result Lwt.t

type entry = {tool: Tool.t; run: handler}

type t = {tools: entry list}

module type PROVIDER = sig
  val registry : t
end

let empty : t = {tools= []}

let default_registry : t =
  let async handler = fun args -> handler args |> Lwt.return in
  let all_tools : entry list =
    [ {tool= List_files.definition; run= async List_files.run}
    ; {tool= Read_file.definition; run= async Read_file.run}
    ; {tool= Write_file.definition; run= async Write_file.run}
    ; {tool= Exec_command.definition; run= async Exec_command.run}
    ; {tool= Fetch_url.definition; run= Fetch_url.run} ]
  in
  {tools= all_tools}

let tools registry = List.map (fun e -> e.tool) registry.tools

let add_tool registry ~(tool : Tool.t) ~(run : handler) =
  {tools= {tool; run} :: registry.tools}

let find_handler registry name =
  match List.find_opt (fun e -> e.tool.name = name) registry.tools with
  | Some e ->
      Some e.run
  | None ->
      None
