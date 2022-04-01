# staging-ocamlrun and enduser-ocamlcompiler 4.12.1

The ocamlrun component is a standalone distribution of OCaml containing
just `ocamlrun` and the OCaml Stdlib.

The ocamlcompiler component installs an OCaml compiler in the end-user
installation directory.

These are component that can be used with [dkml-install-api](https://diskuv.github.io/dkml-install-api/index.html)
to generate installers.

# Usage

## dkml-component-staging-ocamlrun

FIRST, add a dependency to your .opam file:

```ocaml
depends: [
  "dkml-component-staging-ocamlrun"   {>= "4.12.1"}
  # ...
]
```

SECOND, add the package to your currently selected Opam switch:

```bash
opam install dkml-component-staging-ocamlrun
# Alternatively, if on Windows and you have Diskuv OCaml, then:
#   with-dkml opam install dkml-component-staging-ocamlrun
```

THIRD, in your `dune` config file for your registration library include
`dkml-component-staging-ocamlrun.api` as a library as follows:

```lisp
(library
 (public_name dkml-component-something-great)
 (name something_great)
 (libraries
  dkml-install.register
  dune-site
  dkml-component-staging-ocamlrun.api
  ; bos is for constructing command line arguments (ex. Cmd.v)
  bos
  ; ...
  ))
```

FOURTH, in your registration component (ex. `something_great.ml`) use
`spawn_ocamlrun` as follows:

```ocaml
open Bos
open Dkml_install_api

let execute ctx =
  (* ... *)
  let bytecode =
    ctx.Dkml_install_api.Context.path_eval "%{_:share-generic}%/something_great.bc"
  in
  Staging_ocamlrun_api.spawn_ocamlrun
    ctx
    Cmd.(v (Fpath.to_string bytecode) % "arg1" % "arg2" % "etc.")
```

## Testing Locally

FIRST, make sure any changes are committed with `git commit`.

SECOND,

On Windows, assuming you already have installed a DKML distribution, run:

```powershell
# Use an Opam install which include supporting files
with-dkml opam install ./dkml-component-network-ocamlcompiler.opam
& (Join-Path (opam var dkml-component-network-ocamlcompiler:share) staging-files/generic/setup_machine.bc.exe)

# Or directly run it
with-dkml dune exec -- src/installtime_enduser/setup-machine/setup_machine.exe `
    --scripts-dir assets/staging-files/win32 `
    --temp-dir "$env:TEMP\ocamlcompiler" `
    --dkml-dir {specify a DKML directory containing .dkmlroot}
```

For all other operating systems run:

```bash
# Use an Opam install which include supporting files
opam install ./dkml-component-network-ocamlcompiler.opam
"$(opam var dkml-component-network-ocamlcompiler:share)"/staging-files/generic/install.bc.exe

# Directly run without any supporting files
dune exec -- src/installtime_enduser/setup-machine/setup_machine.exe \
    --scripts-dir assets/staging-files/win32 \
    --temp-dir /tmp/ocamlcompiler \
    --dkml-dir {specify a DKML directory containing .dkmlroot}
```

## Contributing

See [the Contributors section of dkml-install-api](https://github.com/diskuv/dkml-install-api/blob/main/contributors/README.md).

## Status

[![Syntax check](https://github.com/diskuv/dkml-component-ocamlcompiler/actions/workflows/syntax.yml/badge.svg)](https://github.com/diskuv/dkml-component-ocamlcompiler/actions/workflows/syntax.yml)
