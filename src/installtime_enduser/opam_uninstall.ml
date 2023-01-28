open Bos
open Dkml_install_api
module Arg = Cmdliner.Arg
module Term = Cmdliner.Term

(* Call the PowerShell (legacy!) uninstall-userprofile.ps1 script *)
let uninstall_start_res ~scripts_dir ~prefix_dir ~is_audit =
  if Sys.win32 then (
    let ( let* ) = Result.bind in
    (* We cannot directly call PowerShell because we likely do not have
       administrator rights.

       BUT BUT this is a Windows batch file that will not handle spaces
       as it translates its command line arguments into PowerShell arguments.
       So any path arguments should have `cygpath -ad` performed on them
       so there are no spaces. *)
    let uninstall_bat = Fpath.(v scripts_dir / "uninstall-userprofile.bat") in
    let to83 = Opam_common.Os.Windows.get_dos83_short_path in
    let* prefix_dir_83 = to83 prefix_dir in
    let cmd =
      Cmd.(
        v (Fpath.to_string uninstall_bat)
        % "-InstallationPrefix" % prefix_dir_83)
    in
    let cmd = if is_audit then Cmd.(cmd % "-AuditOnly") else cmd in
    Logs.info (fun l ->
        l "Uninstalling opam from Windows registry with@ @[%a@]" Cmd.pp cmd);
    log_spawn_onerror_exit ~id:"c144b9e0" cmd;
    Ok ())
  else Ok ()

let uninstall_programdir_res ~prefix_dir =
  (* Only delete the bin/ directory because <programdir>/uninstall.exe must not
     be deleted ... it can't be deleted while we are running it. And it is nice
     to keep the <programdir>/*.log files. *)
  let bindir = Fpath.(prefix_dir / "bin") in
  Dkml_install_api.uninstall_directory_onerror_exit ~id:"bada7bfd" ~dir:bindir
    ~wait_seconds_if_stuck:300.

let uninstall_res ~scripts_dir ~prefix_dir ~is_audit =
  Dkml_install_api.Forward_progress.lift_result __POS__ Fmt.lines
    Dkml_install_api.Forward_progress.stderr_fatallog
  @@ Rresult.R.reword_error (Fmt.str "%a" Rresult.R.pp_msg)
  @@
  let ( let* ) = Rresult.R.bind in
  let* prefix_dir = Fpath.of_string prefix_dir in
  let* () = uninstall_start_res ~scripts_dir ~prefix_dir ~is_audit in
  uninstall_programdir_res ~prefix_dir;
  Ok ()

let uninstall (_ : Log_config.t) scripts_dir prefix_dir is_audit =
  match uninstall_res ~scripts_dir ~prefix_dir ~is_audit with
  | Completed | Continue_progress ((), _) -> ()
  | Halted_progress ec ->
      exit (Dkml_install_api.Forward_progress.Exit_code.to_int_exitcode ec)

let scripts_dir_t =
  Arg.(required & opt (some dir) None & info [ "scripts-dir" ])

let prefix_dir_t =
  Arg.(required & opt (some string) None & info [ "prefix-dir" ])

let is_audit_t = Arg.(value & flag & info [ "audit-only" ])

let uninstall_log style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  Log_config.create ?log_config_style_renderer:style_renderer
    ?log_config_level:level ()

let uninstall_log_t =
  Term.(const uninstall_log $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let () =
  let open Cmdliner in
  let cmd =
    Cmd.v
      (Cmd.info "opam_uninstall.bc" ~doc:"Uninstall opam")
      Term.(
        const uninstall $ uninstall_log_t $ scripts_dir_t $ prefix_dir_t
        $ is_audit_t)
  in
  exit (Cmd.eval cmd)
