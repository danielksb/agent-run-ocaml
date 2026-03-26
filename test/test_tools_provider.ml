open Agentlib

let registry =
  Tool_registry.empty
  |> Tool_registry.add_tool ~tool:Mock_weather_tool.definition
       ~run:Mock_weather_tool.run
