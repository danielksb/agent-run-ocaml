type handler = Yojson.Safe.t -> (string, string) result

type entry = {tool: Tool.t; run: handler}

let entries : entry list =
  [ {tool= Weather_tool.definition; run= Weather_tool.run}
  ; {tool= Math_tools.add_definition; run= Math_tools.add_run}
  ; {tool= Math_tools.multiply_definition; run= Math_tools.multiply_run} ]

let tools () = List.map (fun e -> e.tool) entries

let tools_to_yojson () = List.map (fun e -> Tool.to_yojson e.tool) entries

let find_handler name =
  match List.find_opt (fun e -> e.tool.name = name) entries with
  | Some e ->
      Some e.run
  | None ->
      None
