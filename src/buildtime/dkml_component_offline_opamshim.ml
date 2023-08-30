open Dkml_install_api
open Dkml_install_register

let execute_install ctx =
  let opam_with_ext, withdkml_with_ext, opamputenv_file_opt =
    if Context.Abi_v2.is_windows ctx.Context.target_abi_v2 then
      ( "opam.exe",
        "with-dkml.exe",
        Some Fpath.(Opam_common.opam_share_abi ctx / "bin" / "opam-putenv.exe")
      )
    else ("opam", "with-dkml", None)
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
    Bos.Cmd.(
      v
        (Fpath.to_string
           (ctx.Context.path_eval "%{_:share-generic}%/install_user.bc"))
      %% of_list (Array.to_list (Log_config.to_args ctx.Context.log_config))
      %% of_list
           (match opamputenv_file_opt with
           | Some opamputenv_file ->
               [ "--opam-putenv-exe"; Fpath.to_string opamputenv_file ]
           | None -> [])
      % "--opam-exe"
      % Fpath.to_string opam_exe_file
      % "--with-dkml-exe"
      % Fpath.to_string with_dkml_exe_file
      % "--target-dir"
      % Fpath.to_string (ctx.Context.path_eval "%{prefix}%"))

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
          ( Cmdliner.Cmd.v
              (Cmdliner.Cmd.info subcommand_name ~doc)
              Cmdliner.Term.(const execute_install $ ctx_t),
            fl )
    end)
