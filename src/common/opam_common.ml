(** This package is a temporary home for functions that really belong in
    a standalone repository. THIS DUPLICATES dkml-component-ocamlcompiler!! *)

module Os = struct
  module Windows = struct
    open Bos

    let find_powershell () =
      let ( let* ) = Result.bind in
      let* pwsh_opt = OS.Cmd.find_tool Cmd.(v "pwsh") in
      match pwsh_opt with
      | Some pwsh -> Ok pwsh
      | None -> OS.Cmd.get_tool Cmd.(v "powershell")

    let get_dos83_short_path pth =
      let ( let* ) = Result.bind in
      let* cmd_exe = OS.Env.req_var "COMSPEC" in
      (* DOS variable expansion prints the short 8.3 style file name. *)
      OS.Cmd.run_out
        Cmd.(
          v cmd_exe % "/C" % "for" % "%i" % "in" % "("
          (* Fpath, as desired, prints out in Windows (long) format *)
          % Fpath.to_string pth
          % ")" % "do" % "@echo" % "%~si")
      |> OS.Cmd.to_string ~trim:true
  end
end
