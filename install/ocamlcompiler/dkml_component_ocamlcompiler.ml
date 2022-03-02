open Dkml_install_api
open Dkml_install_register
open Bos

let execute_install ctx =
  Logs.info (fun m ->
      m "The name of the currently installing component is: %s"
        (ctx.Context.eval "%{name}%"));
  Logs.info (fun m ->
      m "The available components are: %s"
        (ctx.Context.eval "%{components:all}%"));
  Logs.info (fun m ->
      m "The install location is: %a" Fpath.pp
        (ctx.Context.path_eval "%{prefix}%"));
  Logs.info (fun m ->
      m "We can place temporary files in: %a" Fpath.pp
        (ctx.Context.path_eval "%{tmp}%"));
  let bytecode = ctx.Context.path_eval "%{_:share}%/generic/install.bc" in
  Logs.info (fun m -> m "Our bytecode executable is at: %a" Fpath.pp bytecode);
  let ocamlrun = ctx.Context.path_eval "%{ocamlrun:share}%/bin/ocamlrun.exe" in
  Logs.info (fun m ->
      m "We will run bytecode using: %a" Fpath.pp
        (ctx.Context.path_eval "%{ocamlrun:share}%/bin/ocamlrun.exe"));
  log_spawn_and_raise
    Cmd.(v (Fpath.to_string ocamlrun) % Fpath.to_string bytecode)

let () =
  let reg = Component_registry.get () in
  Component_registry.add_component reg
    (module struct
      include Default_component_config

      let component_name = "ocamlcompiler"

      let depends_on = [ "ocamlrun"; "unixutils" ]

      let install_user_subcommand ~component_name ~subcommand_name ~ctx_t =
        let doc = "Install the OCaml compiler" in
        Result.ok
        @@ Cmdliner.Term.
             (const execute_install $ ctx_t, info subcommand_name ~doc)
    end)
