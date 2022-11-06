(* Cmdliner 1.0 -> 1.1 deprecated a lot of things. But until Cmdliner 1.1
   is in common use in Opam packages we should provide backwards compatibility.
   In fact, Diskuv OCaml 1.0.0 is not even using Cmdliner 1.1. *)
[@@@alert "-deprecated"]

open Dkml_install_api
open Dkml_install_register
open Bos

let execute_install ctx =
  (* detect whether 32bit host or 64bit host *)
  let srcdir_expr =
    if Sys.int_size <= 32 then "%{staging-opam32:share-abi}%"
    else "%{staging-opam64:share-abi}%"
  in
  Staging_ocamlrun_api.spawn_ocamlrun ctx
    Cmd.(
      v
        (Fpath.to_string
           (ctx.Context.path_eval "%{offline-opam:share-generic}%/install.bc"))
      %% Log_config.to_args ctx.Context.log_config
      % "--source-dir"
      % Fpath.to_string (ctx.Context.path_eval srcdir_expr)
      % "--target-dir"
      % Fpath.to_string (ctx.Context.path_eval "%{prefix}%"))

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
          ( Cmdliner.Term.
              (const execute_install $ ctx_t, info subcommand_name ~doc),
            fl )
    end)
