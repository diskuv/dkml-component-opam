open Dkml_install_register

let run = function Ok () -> () | Error str -> failwith str

let execute_install ctx =
  Format.printf "We can run bytecode using: %s@\n"
    (ctx.Dkml_install_api.Context.path_eval "%{ocamlrun:share}/bin/ocamlrun.exe")

let () =
  let reg = Component_registry.get () in
  run
  @@ Component_registry.add_component reg
       (module struct
         include Dkml_install_api.Default_component_config

         let component_name = "ocamlcompiler"

         let depends_on = [ "ocamlrun" ]

         let install_user_subcommand ~component_name ~subcommand_name ~ctx_t =
           let doc = "Install the OCaml compiler" in
           Result.ok
           @@ Cmdliner.Term.
                (const execute_install $ ctx_t, info subcommand_name ~doc)
       end)
