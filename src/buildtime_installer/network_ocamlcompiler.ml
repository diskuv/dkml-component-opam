open Dkml_install_api
open Dkml_install_register
open Bos

(** [execute_install_admin] will install Visual Studio on Windows, and do
    nothing on any other operating system. *)
let execute_install_admin ctx =
  Logs.info (fun m ->
      m "The install location is: %a" Fpath.pp
        (ctx.Context.path_eval "%{prefix}%"));
  match ctx.host_abi_v2 with
  | Windows_x86_64 | Windows_x86 ->
      let tmppath = ctx.Context.path_eval "%{tmp}%" in
      let bytecode =
        ctx.Context.path_eval "%{_:share}%/generic/setup_machine.bc"
      in
      let dkmlpath =
        ctx.Context.path_eval
          "%{_:share}%/generic/share/dkml/repro/100-compile-ocaml"
      in
      let scriptsdir =
        ctx.Context.path_eval
          ("%{_:share}%/" ^ Context.Abi_v2.to_canonical_string ctx.host_abi_v2)
      in
      let ocamlrun =
        ctx.Context.path_eval "%{staging-ocamlrun:share}%/generic/bin/ocamlrun"
      in
      log_spawn_and_raise
        Cmd.(
          v (Fpath.to_string ocamlrun)
          % Fpath.to_string bytecode % "--dkml-dir" % Fpath.to_string dkmlpath
          % "--temp-dir" % Fpath.to_string tmppath % "--scripts-dir"
          % Fpath.to_string scriptsdir)
  | _ -> ()

let execute_install_user ctx =
  Logs.info (fun m ->
      m "The install location is: %a" Fpath.pp
        (ctx.Context.path_eval "%{prefix}%"));
  (* TODO:
     1. Rename install.bc to setup_userprofile.bc
     2. Modify setup-userprofile.ps1 to allow the deployment slot to
        be at the arbitrary location %{prefix}%. *)
  let bytecode = ctx.Context.path_eval "%{_:share}%/generic/install.bc" in
  let ocamlrun =
    ctx.Context.path_eval "%{staging-ocamlrun:share}%/generic/bin/ocamlrun"
  in
  log_spawn_and_raise
    Cmd.(v (Fpath.to_string ocamlrun) % Fpath.to_string bytecode)

let () =
  let reg = Component_registry.get () in
  Component_registry.add_component reg
    (module struct
      include Default_component_config

      let component_name = "network-ocamlcompiler"

      let depends_on = [ "staging-ocamlrun"; "network-unixutils" ]

      let needs_install_admin () = true

      let install_admin_subcommand ~component_name:_ ~subcommand_name ~ctx_t =
        let doc = "Install Visual Studio from the network" in
        Result.ok
        @@ Cmdliner.Term.
             (const execute_install_admin $ ctx_t, info subcommand_name ~doc)

      let install_user_subcommand ~component_name:_ ~subcommand_name ~ctx_t =
        let doc = "Install the OCaml compiler from the network" in
        Result.ok
        @@ Cmdliner.Term.
             (const execute_install_user $ ctx_t, info subcommand_name ~doc)
    end)
