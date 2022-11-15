(* Cmdliner 1.0 -> 1.1 deprecated a lot of things. But until Cmdliner 1.1
   is in common use in Opam packages we should provide backwards compatibility.
   In fact, Diskuv OCaml 1.0.0 is not even using Cmdliner 1.1. *)
[@@@alert "-deprecated"]

open Dkml_install_api
open Dkml_install_register
open Bos

type important_paths = { scriptsdir : Fpath.t }

let get_important_paths ctx =
  let scriptsdir = ctx.Context.path_eval "%{_:share-abi}%" in
  { scriptsdir }

(* This is a clone of the currently unpublished Context.Abi_v2.word_size *)
let word_size = function
  | Context.Abi_v2.Android_arm64v8a -> 64
  | Android_arm32v7a -> 32
  | Android_x86 -> 32
  | Android_x86_64 -> 64
  | Darwin_arm64 -> 64
  | Darwin_x86_64 -> 64
  | Linux_arm64 -> 64
  | Linux_arm32v6 -> 32
  | Linux_arm32v7 -> 32
  | Linux_x86_64 -> 64
  | Linux_x86 -> 32
  | Windows_x86_64 -> 64
  | Windows_x86 -> 32
  | Windows_arm64 -> 64
  | Windows_arm32 -> 32

let execute_install ctx =
  (* detect whether target is 32bit host or 64bit host *)
  let srcdir_expr =
    if word_size ctx.Context.target_abi_v2 <= 32 then "%{staging-opam32:share-abi}%"
    else "%{staging-opam64:share-abi}%"
  in
  let { scriptsdir } = get_important_paths ctx in
  Staging_ocamlrun_api.spawn_ocamlrun ctx
    Cmd.(
      v
        (Fpath.to_string
           (ctx.Context.path_eval
              "%{offline-opam:share-generic}%/install_userprofile.bc"))
      %% Log_config.to_args ctx.Context.log_config
      % "--source-dir"
      % Fpath.to_string (ctx.Context.path_eval srcdir_expr)
      % "--target-dir"
      % Fpath.to_string (ctx.Context.path_eval "%{prefix}%")
      % "--scripts-dir" % Fpath.to_string scriptsdir)

let execute_uninstall ctx =
  match Context.Abi_v2.is_windows ctx.Context.target_abi_v2 with
  | true ->
      let { scriptsdir } = get_important_paths ctx in
      let bytecode =
        ctx.Context.path_eval "%{_:share-generic}%/uninstall_userprofile.bc"
      in
      let cmd =
        Cmd.(
          v (Fpath.to_string bytecode)
          %% Log_config.to_args ctx.Context.log_config
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
          ( Cmdliner.Term.
              (const execute_install $ ctx_t, info subcommand_name ~doc),
            fl )

      let uninstall_depends_on = [ "staging-ocamlrun" ]

      let uninstall_user_subcommand ~component_name:_ ~subcommand_name ~fl
          ~ctx_t =
        let doc = "Uninstall opam" in
        Dkml_install_api.Forward_progress.Continue_progress
          ( Cmdliner.Term.
              (const execute_uninstall $ ctx_t, info subcommand_name ~doc),
            fl )
    end)
