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

let opam_share_abi ctx =
  (* This is a clone of the currently unpublished Context.Abi_v2.word_size *)
  let word_size = function
    | Dkml_install_api.Context.Abi_v2.Android_arm64v8a -> 64
    | Android_arm32v7a -> 32
    | Android_x86 -> 32
    | Android_x86_64 -> 64
    | Darwin_arm64 -> 64
    | Darwin_x86_64 -> 64
    | Linux_arm64 -> 64
    | Linux_arm32v6 -> 32
    | Linux_arm32v7 -> 32
    | Linux_x86_64 -> 64
    | Linux_x86 -> 32
    | Windows_x86_64 -> 64
    | Windows_x86 -> 32
    | Windows_arm64 -> 64
    | Windows_arm32 -> 32
  in
  let abi_expr =
    (* detect whether target is 32bit host or 64bit host *)
    if word_size ctx.Dkml_install_api.Context.target_abi_v2 <= 32 then
      "%{staging-opam32:share-abi}%"
    else "%{staging-opam64:share-abi}%"
  in
  ctx.Dkml_install_api.Context.path_eval abi_expr
