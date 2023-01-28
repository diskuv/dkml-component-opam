# staging-opam32, staging-opam64 and offline-opam

The `staging-opam32` and `staging-opam64` components make available the Opam binaries (`opam`, `opam-installer`
and on Windows `opam-putenv`) in the staging-files directory.

The `offline-opam` component will install the Opam binaries from `staging-opam32` on 32-bit machines into
the end-user's installation prefix, and from `staging-opam64` on 64-bit machines.

These are components that can be used with [dkml-install-api](https://diskuv.github.io/dkml-install-api/index.html)
to generate installers.

## dkml-component-staging-opam32 and dkml-component-staging-opam64

These components vary by whether distribute 32-bit or 64-bit executables. Sometimes
we only distribute 64-bit for a host operating system (ex. macOS).

### Executables

> `%{staging-opam32:share-abi}%/bin/opam`
>
> `%{staging-opam32:share-abi}%/bin/opam-installer`
>
> `%{staging-opam32:share-abi}%/bin/opam-putenv`
>
> `%{staging-opam64:share-abi}%/bin/opam`
>
> `%{staging-opam64:share-abi}%/bin/opam-installer`
>
> `%{staging-opam64:share-abi}%/bin/opam-putenv`

On Windows the binaries will end with `.exe`.

For a given ABI (ex. `darwin_arm64`) only one of opam32 or opam64's bin/opam
will be present.

If you need to copy these from staging to the end-user's installation prefix, you should copy
the entire `%{staging-opam32:share-abi}%/bin` and
`%{staging-opam64:share-abi}%/bin` directories (one will be empty) as they may contain DLLs
and shared libraries necessary for their operation.

### Documentation

> `%{staging-opam32:share-generic}%/man/man1`
>
> `%{staging-opam64:share-generic}%/man/man1`

Man pages. The man pages will only be available if the corresponding executable is available
in the 32-bit or 64-bit form. If both 32-bit and 64-bit are available, the man pages will
be duplicated.

### Usage

FIRST, add a dependency to your .opam file:

```ocaml
depends: [
  "dkml-component-staging-opam"   {>= "2.1.0"}
  # ...
]
```

SECOND, add the package to your currently selected Opam switch:

```bash
opam install dkml-component-staging-opam
# Alternatively, if on Windows and you have Diskuv OCaml, then:
#   with-dkml opam install dkml-component-staging-opam
```

Be prepared to **wait several minutes** while one or more Opam is being
compiled for your machine.

## Status

[![Syntax check](https://github.com/diskuv/dkml-component-opam/actions/workflows/syntax.yml/badge.svg)](https://github.com/diskuv/dkml-component-opam/actions/workflows/syntax.yml)

| Status                                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [![Asset tests](https://github.com/diskuv/dkml-component-opam/actions/workflows/asset.yml/badge.svg)](https://github.com/diskuv/dkml-component-opam/actions/workflows/asset.yml)    |
| [![Syntax check](https://github.com/diskuv/dkml-component-opam/actions/workflows/syntax.yml/badge.svg)](https://github.com/diskuv/dkml-component-opam/actions/workflows/syntax.yml) |
