open Agentlib

module CliPlatform = Cli.Make (struct
  include Sys

  let exit_with_error () = exit 1

  let stdin_read_all () = In_channel.input_all stdin

  let file_read_all file = open_in file |> In_channel.input_all
end)

let () = CliPlatform.execute ()
