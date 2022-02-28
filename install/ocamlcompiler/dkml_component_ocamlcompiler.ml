open Dkml_install_register
open Bos

let run = function Ok () -> () | Error str -> failwith str

let execute_install ctx =
  Logs.info (fun m ->
      m "The name of the currently installing component is: %s"
        (ctx.Dkml_install_api.Context.eval "%{name}%"));
  Logs.info (fun m ->
      m "The available components are: %s"
        (ctx.Dkml_install_api.Context.eval "%{components:all}%"));
  Logs.info (fun m ->
      m "The install location is: %a" Fpath.pp
        (ctx.Dkml_install_api.Context.path_eval "%{prefix}%"));
  Logs.info (fun m ->
      m "We can place temporary files in: %a" Fpath.pp
        (ctx.Dkml_install_api.Context.path_eval "%{tmp}%"));
  let bytecode =
    ctx.Dkml_install_api.Context.path_eval "%{_:share}%/generic/install.bc"
  in
  Logs.info (fun m -> m "Our bytecode executable is at: %a" Fpath.pp bytecode);
  let ocamlrun =
    ctx.Dkml_install_api.Context.path_eval "%{ocamlrun:share}%/bin/ocamlrun.exe"
  in
  Logs.info (fun m ->
      m "We will run bytecode using: %a" Fpath.pp
        (ctx.Dkml_install_api.Context.path_eval
           "%{ocamlrun:share}%/bin/ocamlrun.exe"));
  match
    OS.Cmd.run_status
      Cmd.(v (Fpath.to_string ocamlrun) % Fpath.to_string bytecode)
  with
  | Ok (`Exited 0) ->
      Logs.info (fun m ->
          m "The bytecode executable %a ran successfully" Fpath.pp bytecode)
  | Ok (`Exited c) ->
      Logs.err (fun m ->
          m "The bytecode executable %a exited with status %d" Fpath.pp bytecode
            c)
  | Ok (`Signaled c) ->
      Logs.err (fun m ->
          m "The bytecode executable %a terminated from a signal %d" Fpath.pp
            bytecode c)
  | Error rmsg ->
      Logs.err (fun m ->
          m "The bytecode executable %a could not be run due to: %a" Fpath.pp
            bytecode Rresult.R.pp_msg rmsg)

let () =
  let reg = Component_registry.get () in
  run
  @@ Component_registry.add_component reg
       (module struct
         include Dkml_install_api.Default_component_config

         let component_name = "ocamlcompiler"

         let depends_on = [ "ocamlrun"; "unixutils" ]

         let install_user_subcommand ~component_name ~subcommand_name ~ctx_t =
           let doc = "Install the OCaml compiler" in
           Result.ok
           @@ Cmdliner.Term.
                (const execute_install $ ctx_t, info subcommand_name ~doc)
       end)
