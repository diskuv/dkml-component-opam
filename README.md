# staging-ocamlrun and enduser-ocamlcompiler 4.12.1

The ocamlrun component is a standalone distribution of OCaml containing
just `ocamlrun` and the OCaml Stdlib.

The ocamlcompiler component installs an OCaml compiler in the end-user
installation directory.

These are component that can be used with [dkml-install-api](https://diskuv.github.io/dkml-install-api/index.html)
to generate installers.

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
