open Dkml_install_register

let run = function Ok () -> () | Error str -> failwith str

let () =
  let reg = Component_registry.get () in
  run
  @@ Component_registry.add_component reg
       (module struct
         let component_name = "ocamlcompiler"
       end)
