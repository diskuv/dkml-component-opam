open Bos
open Cmdliner

let setup_res ~scripts_dir ~dkml_dir ~temp_dir =
  (* We can directly call PowerShell because we have administrator rights.
     But for consistency we will call the .bat like in
     network_ocamlcompiler.ml and setup_userprofile.ml *)
  let setup_machine_bat = Fpath.(v scripts_dir / "setup-machine.bat") in
  let normalized_dkml_path = Fpath.(v dkml_dir |> to_string) in
  let cmd =
    Cmd.(
      v (Fpath.to_string setup_machine_bat)
      % "-DkmlPath" % normalized_dkml_path % "-TempParentPath" % temp_dir
      % "-SkipProgress" % "-AllowRunAsAdmin")
  in
  Logs.info (fun l -> l "Installing Visual Studio with@ @[%a@]" Cmd.pp cmd);
  Result.ok (Dkml_install_api.log_spawn_and_raise cmd)

let setup (_ : Dkml_install_api.Log_config.t) scripts_dir dkml_dir temp_dir =
  match setup_res ~scripts_dir ~dkml_dir ~temp_dir with
  | Ok () -> ()
  | Error msg -> Logs.err (fun l -> l "%a" Rresult.R.pp_msg msg)

let scripts_dir_t =
  Arg.(required & opt (some string) None & info [ "scripts-dir" ])

let dkml_dir_t = Arg.(required & opt (some string) None & info [ "dkml-dir" ])

let tmp_dir_t = Arg.(required & opt (some string) None & info [ "temp-dir" ])

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
      ( const setup $ setup_log_t $ scripts_dir_t $ dkml_dir_t $ tmp_dir_t,
        info "setup-machine.bc" ~doc:"Setup Visual Studio" )
  in
  Term.(exit @@ eval t)