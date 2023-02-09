# Changes

## `2.2.0~alpha0~20221228`

- Is the trunk (`master`) branch of opam up to and include 2022-12-21.
- Includes a patch on 2022-12-28 to distinguish MSYS2 from Cygwin, esp. for
  rsync rather than symlinking which is needed on MSYS2.
- The offline components, used during an opam-only installation, now
  install to a `dkml-opam` rather than `opam` directory so `opam init`
  can use the `opam` directory for its own data (now or in the future).

## `2.2.0~alpha0~20221104`

- Is the trunk (`master`) branch of opam up to and include 2022-11-04.
- Adds `offline-opam` component:
  - Copies the opam/opam-installer/etc. binaries into the installation bin/ directory
  - Modifies the PATH on Windows to include opam.exe:
    - During installation, if LOCALAPPDATA/Programs/DiskuvOCaml/0/bin/opam.exe is in the
      PATH then the opam.exe in `offline-opam` is placed after. Otherwise it is
      placed first.

## `2.2.0~dkml20220801`

opam used in DKML 1.0.0. Contains the following patches for DKML:
* https://github.com/jonahbeckford/opam/commit/b6ba2e113d32045f51bc37c53e949126133f3d3a .
  Use LOCALAPPDATA for initial Opam root
