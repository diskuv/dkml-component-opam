#!/bin/bash
# Runs `make all`, `make opt` and `make install` of findlib for each available mlcross compiler.
#
# Usage: findlib-install.sh FINDLIB_SRCDIR IS_NATIVE MLCROSS_DIR
#
# FINDLIB_PARENT_SRCDIR is the parent of the N source directories of findlib, where
# N is the number of mlcross compilers. `./configure` must have already been performed
# in each of them.
#
# IS_NATIVE should be the Opam variable `ocaml:native`; either "true" or "false".
# If false then `make opt` will not be run.
#
# The generated META files will be in the directory that has been configured in
# findlib-configure.sh; that should be <PREFIX_DIR>/<toolchain>-sysroot/lib/<package>/META.
#
# MLCROSS_DIR is the base directory for zero or more target DKML ABIs (ex.
# android_arm32v7a) that contains bin/ and lib/ subfolders (ex.
# android_arm32v7a/bin). It can be an environment variable, but a default value
# must still be specified on the command line.

set -euf

FINDLIB_PARENT_SRCDIR=$1
shift
IS_NATIVE=$1
shift
if [ -z "${MLCROSS_DIR:-}" ]; then
    MLCROSS_DIR=$1
fi
shift

# Clear environment; no leaks of the host ABI OCaml environment must be present or we may get:
#   Files xxx.cmxa and yyy.cmxa ... make inconsistent assumptions over implementation Dynlink    
unset CAML_LD_LIBRARY_PATH
unset OCAMLLIB
unset OCAML_TOPLEVEL_PATH

# Bash 3.x+ reading of lines into array
CROSSES=()
while IFS='' read -r line; do CROSSES+=("$line"); done < <(find "$MLCROSS_DIR" -mindepth 1 -maxdepth 1)

set +u # Fix bash bug with empty arrays
for _crossdir in "${CROSSES[@]}"; do
    # ex. android_arm32v7a
    dkmlabi=$(basename "$_crossdir")
    cd "$FINDLIB_PARENT_SRCDIR/$dkmlabi"
    
    # Set environment
    PATH="$_crossdir/bin":/usr/bin:/bin

    MAKE_ARGS=()
    # MAKE_ARGS=(
    #     OCAML_CORE_STDLIB="$_crossdir/lib/ocaml"
    #     OCAML_CORE_BIN="$_crossdir/bin"
    #     OCAML_CORE_MAN="$_crossdir/man"
    # )

    make all "${MAKE_ARGS[@]}"
    if [ "$IS_NATIVE" = true ]; then make opt "${MAKE_ARGS[@]}"; fi
    make install "${MAKE_ARGS[@]}"
done
set -u
