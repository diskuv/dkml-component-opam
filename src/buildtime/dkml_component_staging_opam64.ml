open Dkml_install_api
open Dkml_install_register

let register () =
  let reg = Component_registry.get () in
  Component_registry.add_component reg
    (module struct
      include Default_component_config

      let component_name = "staging-opam64"

    end)
