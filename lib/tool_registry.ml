type tool_context = {working_directory: string}

type handler = tool_context -> Yojson.Safe.t -> (string, string) result Lwt.t

type entry = {tool: Tool.t; run: handler}

type t = {tools: entry list}

module type PROVIDER = sig
  val registry : t
end

let empty : t = {tools= []}

let default_registry : t =
  let async handler = fun context args -> handler context args |> Lwt.return in
  let with_working_directory
      (run :
        ?working_directory:string -> Yojson.Safe.t -> (string, string) result)
      context args =
    run ~working_directory:context.working_directory args
  in
  let all_tools : entry list =
    [ {tool= List_files.definition; run= async (with_working_directory List_files.run)}
    ; {tool= Read_file.definition; run= async (with_working_directory Read_file.run)}
    ; { tool= Write_file.definition
      ; run= async (with_working_directory Write_file.run) }
    ; { tool= Exec_command.definition
      ; run= async (fun _context args -> Exec_command.run args) }
    ; {tool= Fetch_url.definition; run= (fun _context args -> Fetch_url.run args)}
    ]
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
