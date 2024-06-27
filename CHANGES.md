# Changes

## `2.2.0~rc1`

- <https://discuss.ocaml.org/t/ann-opam-2-2-0-rc1-release/14842>

## `2.2.0~beta3`

- <https://discuss.ocaml.org/t/ann-opam-2-2-0-beta3/14772>

## `2.2.0~beta2`

## `2.2.0~alpha3~20230918`

- (Not now but will have) the trunk (`master`) branch of opam up to and include 2023-09-18 commit
  `b0cb137edebc5e7d7ac1e650086e3be5800ae743`.
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
