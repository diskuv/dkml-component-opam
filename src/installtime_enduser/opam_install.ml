(* Cmdliner 1.0 -> 1.1 deprecated a lot of things. But until Cmdliner 1.1
   is in common use in Opam packages we should provide backwards compatibility.
   In fact, Diskuv OCaml 1.0.0 is not even using Cmdliner 1.1. *)
[@@@alert "-deprecated"]

open Bos

type t = { source_dir : Fpath.t; target_dir : Fpath.t }

let create ~source_dir ~target_dir = { source_dir; target_dir }

(* Call the PowerShell (legacy!) setup-userprofile.ps1 script *)
let setup_remainder_res ~scripts_dir ~prefix_dir =
  if Sys.win32 then (
    let ( let* ) = Result.bind in
    (* We cannot directly call PowerShell because we likely do not have
       administrator rights.

       BUT BUT this is a Windows batch file that will not handle spaces
       as it translates its command line arguments into PowerShell arguments.
       So any path arguments should have `cygpath -ad` performed on them
       so there are no spaces. *)
    let setup_bat = Fpath.(v scripts_dir / "setup-userprofile.bat") in
    let to83 = Opam_common.Os.Windows.get_dos83_short_path in
    let* prefix_dir_83 = to83 prefix_dir in
    let cmd =
      Cmd.(
        v (Fpath.to_string setup_bat)
        % "-AllowRunAsAdmin" % "-InstallationPrefix" % prefix_dir_83)
    in
    Logs.info (fun l ->
        l "Installing opam into Windows Registry with@ @[%a@]" Cmd.pp cmd);
    Dkml_install_api.log_spawn_onerror_exit ~id:"ec8c18bb" cmd;
    Ok ())
  else Ok ()

let install_res ~scripts_dir ~source_dir ~target_dir =
  Dkml_install_api.Forward_progress.lift_result __POS__ Fmt.lines
    Dkml_install_api.Forward_progress.stderr_fatallog
  @@ Rresult.R.reword_error (Fmt.str "%a" Rresult.R.pp_msg)
  @@
  let ( let* ) = Rresult.R.bind in

  let* () =
    match Diskuvbox.copy_dir ~src:source_dir ~dst:target_dir () with
    | Ok () -> Ok ()
    | Error msg -> failwith msg
  in
  setup_remainder_res ~scripts_dir ~prefix_dir:target_dir

let install (_ : Dkml_install_api.Log_config.t) scripts_dir source_dir
    target_dir =
  match install_res ~scripts_dir ~source_dir ~target_dir with
  | Completed | Continue_progress ((), _) -> ()
  | Halted_progress ec ->
      exit (Dkml_install_api.Forward_progress.Exit_code.to_int_exitcode ec)

let scripts_dir_t =
  Cmdliner.Arg.(required & opt (some string) None & info [ "scripts-dir" ])

let source_dir_t =
  let x =
    Cmdliner.Arg.(
      required & opt (some dir) None & info ~doc:"Source path" [ "source-dir" ])
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
  let t =
    Cmdliner.Term.
      ( const install $ setup_log_t $ scripts_dir_t $ source_dir_t $ target_dir_t,
        info "opam-install.bc" ~doc:"Install opam" )
  in
  Cmdliner.Term.(exit @@ eval t)
