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

let execute_install ctx =
  let { scriptsdir } = get_important_paths ctx in
  let opam_with_ext, withdkml_with_ext =
    if Context.Abi_v2.is_windows ctx.Context.target_abi_v2 then
      ("opam.exe", "with-dkml.exe")
    else ("opam", "with-dkml")
  in
  let opam_exe_file =
    Fpath.(Opam_common.opam_share_abi ctx / "bin" / opam_with_ext)
  in
  let with_dkml_exe_file =
    Fpath.(
      ctx.Context.path_eval "%{staging-withdkml:share-abi}%/bin"
      / withdkml_with_ext)
  in
  Staging_ocamlrun_api.spawn_ocamlrun ctx
    Cmd.(
      v
        (Fpath.to_string
           (ctx.Context.path_eval
              "%{offline-opamshim:share-generic}%/install_user.bc"))
      %% Log_config.to_args ctx.Context.log_config
      % "--opam-exe"
      % Fpath.to_string opam_exe_file
      % "--with-dkml-exe"
      % Fpath.to_string with_dkml_exe_file
      % "--target-dir"
      % Fpath.to_string (ctx.Context.path_eval "%{prefix}%")
      % "--scripts-dir" % Fpath.to_string scriptsdir)

let register () =
  let reg = Component_registry.get () in
  Component_registry.add_component reg
    (module struct
      include Default_component_config

      let component_name = "offline-opamshim"

      let install_depends_on =
        [
          "staging-ocamlrun";
          "staging-opam32";
          "staging-opam64";
          "staging-withdkml";
        ]

      let install_user_subcommand ~component_name:_ ~subcommand_name ~fl ~ctx_t
          =
        let doc = "Install opam" in
        Dkml_install_api.Forward_progress.Continue_progress
          ( Cmdliner.Term.
              (const execute_install $ ctx_t, info subcommand_name ~doc),
            fl )
    end)
