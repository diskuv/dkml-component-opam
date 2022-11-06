type t = { source_dir : Fpath.t; target_dir : Fpath.t }

let create ~source_dir ~target_dir = { source_dir; target_dir }

let install { source_dir; target_dir } =
  match Diskuvbox.copy_dir ~src:source_dir ~dst:target_dir () with
  | Ok () -> ()
  | Error msg -> failwith msg

let () =
  (* Arg parsing *)
  let anon_fun (_ : string) =
    failwith "No commandline arguments supported for ocamlrun opam_install.ml"
  in
  let source_dir = ref "" in
  let target_dir = ref "" in
  Arg.(
    parse
      [
        ("--source-dir", Set_string source_dir, "Source path");
        ("--target-dir", Set_string target_dir, "Destination path");
      ]
      anon_fun "Install the desktop binaries in --source-dir into --target-dir");
  if !source_dir = "" then (
    prerr_endline "FATAL: The --source-dir DIR option is required.";
    exit 1);
  if !target_dir = "" then (
    prerr_endline "FATAL: The --target-dir DIR option is required.";
    exit 1);

  let installer =
    create ~source_dir:(Fpath.v !source_dir) ~target_dir:(Fpath.v !target_dir)
  in
  install installer
