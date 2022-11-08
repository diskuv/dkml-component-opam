open Cmdliner

type t = { source_dir : Fpath.t; target_dir : Fpath.t }

let create ~source_dir ~target_dir = { source_dir; target_dir }

let install (_ : Dkml_install_api.Log_config.t) source_dir target_dir =
  match Diskuvbox.copy_dir ~src:source_dir ~dst:target_dir () with
  | Ok () -> ()
  | Error msg -> failwith msg

let source_dir_t =
  let x =
    Arg.(
      required & opt (some dir) None & info ~doc:"Source path" [ "source-dir" ])
  in
  Term.(const Fpath.v $ x)

let target_dir_t =
  let x =
    Arg.(
      required
      & opt (some string) None
      & info ~doc:"Target path" [ "target-dir" ])
  in
  Term.(const Fpath.v $ x)

let setup_log style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  Dkml_install_api.Log_config.create ?log_config_style_renderer:style_renderer
    ?log_config_level:level ()

let setup_log_t =
  Term.(const setup_log $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let () =
  let t =
    Term.
      ( const install $ setup_log_t $ source_dir_t $ target_dir_t,
        info "opam-install.bc" ~doc:"Install opam" )
  in
  Term.(exit @@ eval t)