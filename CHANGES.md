# Changes

## `2.2.0~alpha0~20221228-r3`

- Is a sibling fork of `2.2.0-beta2-20240409` with divergence from `v2.2.0-alpha-20221228-r2` to keep working opam 2.2.0~alpha0
  - Drop: Prepare new version (2/2) (`7445007c04e949590ece05786f88a40d82c463b1`)
  - Drop: Prepare new version (1/2) (`75d9fe44b7a98c7f9b6f74cdddd99e93cfd4ee0b`)
  - Conflict resolve: Docs and copy-editing of text (`0d5d3ebc3b0294cab33be04feeada61217aefb8c`)
  - Drop: Use older alpha0 opam commit (`bbd751831b9da3f2ebdb53f4c45552ef91cd331e`)
  - Drop: Sync opam extra-source with archives from src_ext/ (`aafa8d9e842eb40fb42dd83a8aaf2c544bbdac8f`)
  - Partial: Start 2.2.0~alpha3~20230918 (`68578d591fe132042b22fb9f3fd2e9605afdc6f0`)
- Upgrade lower bounds: dkml-install-0.5.1+, cmdliner-1.2.0+, diskuvbox-0.2.0+,
  and dkml-runtime-common-2.0.3+.
- Loosen upper bounds: ocaml not restricted to under 5.0

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
