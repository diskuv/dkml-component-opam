# opam components distributed by DkML

## Making a new version

> It is perfectly fine to do all of this on a Unix machine, even if you intend to distribute to Windows users.

> The following assumes you have a Unix shell. On Windows with DkML installed you can use `with-dkml bash` to get one.

1. Do the following parts of the Prereqs section in [DEVELOPMENT.md](./DEVELOPMENT.md):

   ```sh
   # On Windows
   dkml init

   # On Unix
   opam switch create . --no-install --repos 'default,diskuv-2.1.0=git+https://github.com/diskuv/diskuv-opam-repository.git#2.1.0' --packages dkml-base-compiler.4.14.0~v2.1.0
   ```
2. Edit the `(version ...)` in [dune-project](./dune-project).
   There are guidelines in that file, especially about including the date in the version string.
3. Add an entry to [CHANGES.md](./CHANGES.md).
4. Add a new opam version inside `extra-source "dl/opam.tar.gz"` in [dkml-component-staging-opam64.opam.template](./dkml-component-staging-opam64.opam.template) and [dkml-component-staging-opam32.opam.template](./dkml-component-staging-opam32.opam.template).
   - Update the `src` and `checksum` fields. The `src` should be the "Source code (tar.gz)" asset link for the latest release in https://github.com/ocaml/opam/releases (or better yet use a permanent download link).
   - **Update the changelog comments in this section.** That means you clone the *new* `src` and `checksum` fields as *comments*.
5. Do:

   ```sh
   opam exec -- dune build *.opam
   git add CHANGES.md dune-project *.opam *.opam.template
   git commit -m "Prepare new version (1/2)"

   opam remove dkml-component-staging-opam64 -y
   opam install ./dkml-component-staging-opam64.opam --keep-build-dir
   ```
6. You will need to place the output of the following command into the **BEGIN OPAM ARCHIVES** sections of [dkml-component-staging-opam64.opam.template](./dkml-component-staging-opam64.opam.template) and [dkml-component-staging-opam32.opam.template](./dkml-component-staging-opam32.opam.template):

   ```sh
   opamdl="$(opam var dkml-component-staging-opam64:build)/dl/opam"

   join <(awk '$1~/^URL_[a-z]/{sub(/URL_/,"",$1); print $1,"URL",$NF}' "${opamdl}/src_ext/Makefile" "${opamdl}/src_ext/Makefile.sources") <(awk '$1~/^MD5_[a-z]/{sub(/MD5_/,"",$1); print $1,"MD5",$NF}' "${opamdl}/src_ext/Makefile" "${opamdl}/src_ext/Makefile.sources") | awk -v dq='"' '$2=="URL" && $4=="MD5"{name=$3; sub(".*/", "",name); printf "extra-source %sdl/opam/src_ext/archives/%s%s {\n  src: %s%s%s\n  checksum: [\n    %smd5=%s%s\n  ]\n}\n", dq,name,dq, dq,$3,dq, dq,$5,dq }'
   ```
7. Do:

   ```sh
   opam exec -- dune build *.opam
   git add *.opam *.opam.template
   git commit -m "Prepare new version (2/2)"

   opam install ./dkml-component-common-opam.opam ./dkml-component-staging-opam32.opam ./dkml-component-staging-opam64.opam ./dkml-component-offline-opam.opam --keep-build-dir --yes

   # See some important OS-specific files that will be packaged as part of the installer
   find "$(opam var dkml-component-offline-opam:share)/staging-files"
   find "$(opam var dkml-component-staging-opam64:share)/staging-files"
   ```

8. Do:

   ```sh
   # 2.2.0~beta2~20240409 is tagged as 2.2.0-beta2-20240409
   tagversion=$(awk '/\(version / { sub(/)/, ""); gsub(/~/, "-"); print $2 }' dune-project)
   git tag "$tagversion"
   git push origin "$tagversion"
   ```

That should kick of GitHub Actions which will build for Windows, macOS and Linux.

**FINALLY**, start at step 2 of [dkml-installer-opam's "Making a new version"](https://github.com/diskuv/dkml-installer-opam?tab=readme-ov-file#making-a-new-version) to complete the instructions for publishing so `winget install opam` picks up your changes.

## Components: staging-opam32, staging-opam64 and offline-opam

The `staging-opam32` and `staging-opam64` components make available the Opam binaries (`opam`, `opam-installer`
and on Windows `opam-putenv`) in the `staging-files` directory.

The `offline-opam` component will install the Opam binaries from `staging-opam32` on 32-bit machines into
the end-user's installation prefix, and from `staging-opam64` on 64-bit machines.

These are components that can be used with [dkml-install-api](https://diskuv.github.io/dkml-install-api/index.html)
to generate the `winget` / `setup.exe` installers.

## dkml-component-staging-opam32 and dkml-component-staging-opam64

DkML components vary by whether 32-bit or 64-bit executables are distributed. Sometimes
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
| [![Build tests](https://github.com/diskuv/dkml-component-opam/actions/workflows/dkml.yml/badge.svg)](https://github.com/diskuv/dkml-component-opam/actions/workflows/dkml.yml)      |
| [![Syntax check](https://github.com/diskuv/dkml-component-opam/actions/workflows/syntax.yml/badge.svg)](https://github.com/diskuv/dkml-component-opam/actions/workflows/syntax.yml) |
