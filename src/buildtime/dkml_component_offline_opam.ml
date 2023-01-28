open Dkml_install_api
open Dkml_install_register

type important_paths = { scriptsdir : Fpath.t }

let get_important_paths ctx =
  let scriptsdir = ctx.Context.path_eval "%{_:share-abi}%" in
  { scriptsdir }

(* This is a clone of the currently unpublished Context.Abi_v2.word_size *)
let execute_install ctx =
  let { scriptsdir } = get_important_paths ctx in
  Staging_ocamlrun_api.spawn_ocamlrun ctx
    Bos.Cmd.(
      v
        (Fpath.to_string
           (ctx.Context.path_eval
              "%{_:share-generic}%/install_user.bc"))
      %% of_list (Array.to_list (Log_config.to_args ctx.Context.log_config))
      % "--source-dir"
      % Fpath.to_string (Opam_common.opam_share_abi ctx)
      % "--target-dir"
      % Fpath.to_string (ctx.Context.path_eval "%{prefix}%")
      % "--scripts-dir" % Fpath.to_string scriptsdir)

let execute_uninstall ctx =
  match Context.Abi_v2.is_windows ctx.Context.target_abi_v2 with
  | true ->
      let { scriptsdir } = get_important_paths ctx in
      let bytecode =
        ctx.Context.path_eval "%{_:share-generic}%/uninstall_user.bc"
      in
      let cmd =
        Bos.Cmd.(
          v (Fpath.to_string bytecode)
          %% of_list (Array.to_list (Log_config.to_args ctx.Context.log_config))
          % "--prefix"
          % Fpath.to_string (ctx.Context.path_eval "%{prefix}%")
          % "--scripts-dir" % Fpath.to_string scriptsdir)
      in
      Staging_ocamlrun_api.spawn_ocamlrun ctx cmd
  | false -> ()

let register () =
  let reg = Component_registry.get () in
  Component_registry.add_component reg
    (module struct
      include Default_component_config

      let component_name = "offline-opam"

      let install_depends_on =
        [ "staging-ocamlrun"; "staging-opam32"; "staging-opam64" ]

      let install_user_subcommand ~component_name:_ ~subcommand_name ~fl ~ctx_t
          =
        let doc = "Install opam" in
        Dkml_install_api.Forward_progress.Continue_progress
          ( Cmdliner.Cmd.v
              (Cmdliner.Cmd.info subcommand_name ~doc)
              Cmdliner.Term.(const execute_install $ ctx_t),
            fl )

      let uninstall_depends_on = [ "staging-ocamlrun" ]

      let uninstall_user_subcommand ~component_name:_ ~subcommand_name ~fl
          ~ctx_t =
        let doc = "Uninstall opam" in
        Dkml_install_api.Forward_progress.Continue_progress
          ( Cmdliner.Cmd.v
              (Cmdliner.Cmd.info subcommand_name ~doc)
              Cmdliner.Term.(const execute_uninstall $ ctx_t),
            fl )
    end)
