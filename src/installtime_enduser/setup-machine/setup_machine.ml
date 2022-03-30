open Bos
open Cmdliner

let setup_res ~scripts_dir ~dkml_dir ~temp_dir =
  let ( let* ) = Result.bind in
  let* powershell = Ocamlcompiler_common.Os.Windows.find_powershell () in
  let setup_machine_ps1 = Fpath.(v scripts_dir / "setup-machine.ps1") in
  let normalized_dkml_path = Fpath.(v dkml_dir |> to_string) in
  Result.ok
  @@ Dkml_install_api.log_spawn_and_raise
       Cmd.(
         v (Fpath.to_string powershell)
         % Fpath.to_string setup_machine_ps1
         % "-DkmlPath" % normalized_dkml_path % "-TempParentPath" % temp_dir
         % "-SkipProgress" % "-AllowRunAsAdmin")

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