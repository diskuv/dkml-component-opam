open Bos
open Cmdliner
open Dkml_install_api

let setup_res ~scripts_dir ~dkml_dir ~temp_dir ~abi ~prefix_dir ~msys2_dir =
  (* We cannot directly call PowerShell because we likely do not have
     administrator rights *)
  let setup_bat = Fpath.(v scripts_dir / "setup-userprofile.bat") in
  let normalized_dkml_path = Fpath.(v dkml_dir |> to_string) in
  let cmd =
    Cmd.(
      v (Fpath.to_string setup_bat)
      % "-InstallationPrefix" % prefix_dir % "-MSYS2Dir" % msys2_dir
      % "-DkmlPath" % normalized_dkml_path % "-DkmlHostAbi"
      % Context.Abi_v2.to_canonical_string abi
      % "-TempParentPath" % temp_dir % "-SkipProgress")
  in
  Logs.info (fun l ->
      l "Installing Git, OCaml and other tools with@ @[%a@]" Cmd.pp cmd);
  Result.ok (log_spawn_and_raise cmd)

let setup (_ : Log_config.t) scripts_dir dkml_dir temp_dir abi prefix_dir
    msys2_dir =
  match
    setup_res ~scripts_dir ~dkml_dir ~temp_dir ~abi ~prefix_dir ~msys2_dir
  with
  | Ok () -> ()
  | Error msg -> Logs.err (fun l -> l "%a" Rresult.R.pp_msg msg)

let scripts_dir_t =
  Arg.(required & opt (some dir) None & info [ "scripts-dir" ])

let dkml_dir_t = Arg.(required & opt (some dir) None & info [ "dkml-dir" ])

let tmp_dir_t = Arg.(required & opt (some dir) None & info [ "temp-dir" ])

let prefix_dir_t =
  Arg.(required & opt (some string) None & info [ "prefix-dir" ])

let msys2_dir_t = Arg.(required & opt (some dir) None & info [ "msys2-dir" ])

let abi_t =
  let open Context.Abi_v2 in
  let l =
    List.init
      (max - min + 1)
      (fun i ->
        match of_enum (min + i) with
        | Some v -> Some (to_canonical_string v, v)
        | None -> None)
    |> List.filter_map Fun.id
  in
  Arg.(required & opt (some (enum l)) None & info [ "abi" ])

let setup_log style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  Log_config.create ?log_config_style_renderer:style_renderer
    ?log_config_level:level ()

let setup_log_t =
  Term.(const setup_log $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let () =
  let t =
    Term.
      ( const setup $ setup_log_t $ scripts_dir_t $ dkml_dir_t $ tmp_dir_t
        $ abi_t $ prefix_dir_t $ msys2_dir_t,
        info "setup-userprofile.bc"
          ~doc:
            "Install Git for Windows 2.33.0, compiles OCaml and install \
             several useful OCaml programs" )
  in
  Term.(exit @@ eval t)