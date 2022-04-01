val spawn_ocamlrun : Dkml_install_api.Context.t -> Bos.Cmd.t -> unit
(** [spawn_ocamlrun ctx cmd] runs the OCaml bytecode command line
    [cmd = Cmd.(v "something.bc" % "arg1" % "arg2" % "etc.")]
    using the ocamlrun.exe available in the context [ctx].

    {3 Environment variables}

    Confer: {{:https://ocaml.org/manual/runtime.html} The runtime system (ocamlrun)}

    The following environment variables are set while running ocamlrun.exe:

    - [OCAMLRUNPARAM]: Set to ["b"] unless [OCAMLRUNPARAM] was already set to
      a non-empty value.
    - [OCAMLLIB]: Set to the standard library directory containing ["ld.conf"]
      in the context [ctx].
    *)
