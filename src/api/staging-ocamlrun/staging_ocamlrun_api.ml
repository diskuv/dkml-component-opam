open Bos
open Dkml_install_api
open Astring

let is_not_defined name env =
  match String.Map.find name env with
  | None -> true
  | Some "" -> true
  | Some _ -> false

let ocamlrun_exe { Dkml_install_api.Context.path_eval; _ } =
  path_eval "%{staging-ocamlrun:share-abi}%/bin/ocamlrun"

let lib_ocaml { Dkml_install_api.Context.path_eval; _ } =
  path_eval "%{staging-ocamlrun:share-abi}%/lib/ocaml"

let spawn_ocamlrun ctx cmd =
  let new_cmd = Cmd.(v (Fpath.to_string (ocamlrun_exe ctx)) %% cmd) in
  Logs.info (fun m -> m "Running bytecode with: %a" Cmd.pp new_cmd);
  let ( let* ) = Result.bind in
  let sequence =
    let* new_env = OS.Env.current () in
    let new_env =
      if is_not_defined "OCAMLRUNPARAM" new_env then
        String.Map.add "OCAMLRUNPARAM" "b" new_env
      else new_env
    in
    let new_env =
      String.Map.add "OCAMLLIB" (Fpath.to_string (lib_ocaml ctx)) new_env
    in
    OS.Cmd.run_status ~env:new_env new_cmd
  in
  match sequence with
  | Ok (`Exited 0) ->
      Logs.info (fun m -> m "The command %a ran successfully" Cmd.pp cmd)
  | Ok (`Exited c) ->
      raise
        (Installation_error
           (Fmt.str "The command %a exited with status %d" Cmd.pp cmd c))
  | Ok (`Signaled c) ->
      raise
        (Installation_error
           (Fmt.str "The command %a terminated from a signal %d" Cmd.pp cmd c))
  | Error rmsg ->
      raise
        (Installation_error
           (Fmt.str "The command %a could not be run due to: %a" Cmd.pp cmd
              Rresult.R.pp_msg rmsg))
