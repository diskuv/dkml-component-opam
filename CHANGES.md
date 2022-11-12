# Changes

## `2.2.0~alpha0~20221104`

- Is the trunk (`master`) branch of opam up to and include 2022-11-04.
- Adds `offline-opam` component:
  - Copies the opam/opam-installer/etc. binaries into the installation bin/ directory
  - Modifies the PATH on Windows to include opam.exe:
    - During installation, if LOCALAPPDATA/Programs/DiskuvOCaml/0/bin/opam.exe is in the
      PATH then the opam.exe in `offline-opampp` is placed after. Otherwise it is
      placed first.

## `2.2.0~dkml20220801`

opam used in DKML 1.0.0. Contains the following patches for DKML:
* https://github.com/jonahbeckford/opam/commit/b6ba2e113d32045f51bc37c53e949126133f3d3a .
  Use LOCALAPPDATA for initial Opam root
