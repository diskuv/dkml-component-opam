let install_res ~opam_exe ?opam_putenv_exe ~with_dkml_exe ~target_dir () =
  Dkml_install_api.Forward_progress.lift_result __POS__ Fmt.lines
    Dkml_install_api.Forward_progress.stderr_fatallog
  @@
  let ( let* ) = Rresult.R.bind in
  let ext = Fpath.get_ext opam_exe in
  let* () =
    (* opam -> opam-real *)
    Diskuvbox.copy_file ~src:opam_exe
      ~dst:Fpath.(target_dir / "bin" / ("opam-real" ^ ext))
      ()
  in
  let* () =
    (* opam-putenv.exe -> opam-putenv.exe *)
    match opam_putenv_exe with
    | Some opam_putenv_exe ->
        Diskuvbox.copy_file ~src:opam_putenv_exe
          ~dst:Fpath.(target_dir / "bin" / ("opam-putenv" ^ ext))
          ()
    | None -> Ok ()
  in
  (* with-dkml -> opam *)
  Diskuvbox.copy_file ~src:with_dkml_exe
    ~dst:Fpath.(target_dir / "bin" / ("opam" ^ ext))
    ()

let install (_ : Dkml_install_api.Log_config.t) opam_exe opam_putenv_exe_opt
    with_dkml_exe target_dir =
  match
    install_res ~opam_exe ?opam_putenv_exe:opam_putenv_exe_opt ~with_dkml_exe
      ~target_dir ()
  with
  | Completed | Continue_progress ((), _) -> ()
  | Halted_progress ec ->
      exit (Dkml_install_api.Forward_progress.Exit_code.to_int_exitcode ec)

let opam_exe_t =
  let x =
    Cmdliner.Arg.(
      required
      & opt (some file) None
      & info ~doc:"The location of opam.exe on Windows or opam on *nix"
          [ "opam-exe" ])
  in
  Cmdliner.Term.(const Fpath.v $ x)

let opam_putenv_exe_opt_t =
  let x =
    Cmdliner.Arg.(
      value
      & opt (some file) None
      & info
          ~doc:
            "The location of opam-putenv.exe on Windows. It should not be \
             specified for *nix"
          [ "opam-putenv-exe" ])
  in
  Cmdliner.Term.(const (Option.map Fpath.v) $ x)

let with_dkml_exe_t =
  let x =
    Cmdliner.Arg.(
      required
      & opt (some file) None
      & info
          ~doc:"The location of with-dkml.exe on Windows or with-dkml on *nix"
          [ "with-dkml-exe" ])
  in
  Cmdliner.Term.(const Fpath.v $ x)

let target_dir_t =
  let x =
    Cmdliner.Arg.(
      required
      & opt (some string) None
      & info ~doc:"Target path" [ "target-dir" ])
  in
  Cmdliner.Term.(const Fpath.v $ x)

let setup_log style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  Dkml_install_api.Log_config.create ?log_config_style_renderer:style_renderer
    ?log_config_level:level ()

let setup_log_t =
  Cmdliner.Term.(
    const setup_log $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let () =
  let open Cmdliner in
  let cmd =
    Cmd.v
      (Cmd.info "opamshim-install.bc" ~doc:"Install opam shim")
      Term.(
        const install $ setup_log_t $ opam_exe_t $ opam_putenv_exe_opt_t
        $ with_dkml_exe_t $ target_dir_t)
  in
  exit (Cmd.eval cmd)
