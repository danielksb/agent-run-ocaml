type handler = Yojson.Safe.t -> (string, string) result

type entry = {tool: Tool.t; run: handler}

type t = {tools: entry list}

module type PROVIDER = sig
  val registry : t
end

let empty : t = {tools= []}

let add_entry registry entry = {tools= entry :: registry.tools}

let add_tool registry ~(tool : Tool.t) ~(run : handler) =
  add_entry registry {tool; run}

let all_tools : entry list =
  [ {tool= List_files.definition; run= List_files.run}
  ; {tool= Read_file.definition; run= Read_file.run}
  ; {tool= Write_file.definition; run= Write_file.run}
  ; {tool= Exec_program.definition; run= Exec_program.run} ]

let default_registry () = {tools= all_tools}

let tools registry = List.map (fun e -> e.tool) registry.tools

let tools_to_yojson registry =
  List.map (fun e -> Tool.to_yojson e.tool) registry.tools

let find_handler registry name =
  match List.find_opt (fun e -> e.tool.name = name) registry.tools with
  | Some e ->
      Some e.run
  | None ->
      None
