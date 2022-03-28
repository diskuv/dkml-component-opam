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

```bash
with-dkml opam install ./dkml-component-network-ocamlcompiler.opam
& (Join-Path (opam var dkml-component-network-ocamlcompiler:share) staging-files/generic/install.bc.exe)
```

For all other operating systems run:

```bash
opam install ./dkml-component-network-ocamlcompiler.opam
"$(opam var dkml-component-network-ocamlcompiler:share)"/staging-files/generic/install.bc.exe
```

## Contributing

See [the Contributors section of dkml-install-api](https://github.com/diskuv/dkml-install-api/blob/main/contributors/README.md).

## Status

[![Syntax check](https://github.com/diskuv/dkml-component-ocamlcompiler/actions/workflows/syntax.yml/badge.svg)](https://github.com/diskuv/dkml-component-ocamlcompiler/actions/workflows/syntax.yml)
