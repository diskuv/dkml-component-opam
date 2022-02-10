#!/bin/bash
# Runs `tar xfz` and `./configure` of findlib for each available mlcross compiler.
#
# Usage: findlib-configure.sh FINDLIB_TARGZ FINDLIB_VERSION FINDLIB_PARENT_SRCDIR IS_PREINSTALLED PREFIX_DIR MLCROSS_DIR
#
# FINDLIB_TARGZ is the findlib tar ball.
#
# FINDLIB_VERSION is the version number (ex. 1.9.1).
#
# FINDLIB_PARENT_SRCDIR is the parent directory for the 0 or more source directory of findlib.
# There will be one source directory for each mlcross compiler. `./configure` will
# be performed in each source directory..
#
# IS_PREINSTALLED should be the Opam variable `ocaml:preinstalled`; either "true" or "false".
# If true then `-no-topfind` will be a ./configure option; otherwise `-no-camlp4` will be an option.
#
# PREFIX_DIR is the Opam switch prefix directory that contains
# `lib/findlib.conf` among others.
#
# The configured findlib source directories will be
# <FINDLIB_PARENT_SRCDIR>/<toolchain>/
#
# The META files will be configured to be generated in
# <PREFIX_DIR>/<toolchain>-sysroot/lib/<package>/META.
#
# MLCROSS_DIR is the base directory for zero or more target DKML ABIs (ex.
# android_arm32v7a) that contains bin/ and lib/ subfolders (ex.
# android_arm32v7a/bin). It can be an environment variable, but a default value
# must still be specified on the command line.

set -euf

FINDLIB_TARGZ=$1
shift
FINDLIB_VERSION=$1
shift
FINDLIB_PARENT_SRCDIR=$1
shift
IS_PREINSTALLED=$1
shift
PREFIX_DIR=$1
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

    # Set environment
    PATH="$_crossdir/bin":/usr/bin:/bin

    # Untar tar ball
    install -d "$FINDLIB_PARENT_SRCDIR/$dkmlabi"
    tar xCfz "$FINDLIB_PARENT_SRCDIR/$dkmlabi" "$FINDLIB_TARGZ"
    cd "$FINDLIB_PARENT_SRCDIR/$dkmlabi"

    # Remove the findlib-1.9.1/ top directory
    find findlib-"$FINDLIB_VERSION" -mindepth 1 -maxdepth 1 -exec mv {} "$FINDLIB_PARENT_SRCDIR/$dkmlabi" \;
    rmdir findlib-"$FINDLIB_VERSION"

    # Configure
    sysroot_bin_buildhost="$PREFIX_DIR/$dkmlabi-sysroot/bin"
    sysroot_lib_buildhost="$PREFIX_DIR/$dkmlabi-sysroot/lib"
    sysroot_man_buildhost="$PREFIX_DIR/$dkmlabi-sysroot/man"
    if [ "$IS_PREINSTALLED" = true ]; then
        ./configure -config "$sysroot_lib_buildhost/findlib.conf" -bindir "$sysroot_bin_buildhost" -sitelib "$sysroot_lib_buildhost" -mandir "$sysroot_man_buildhost" -no-topfind
    else
        ./configure -config "$sysroot_lib_buildhost/findlib.conf" -bindir "$sysroot_bin_buildhost" -sitelib "$sysroot_lib_buildhost" -mandir "$sysroot_man_buildhost" -no-camlp4
    fi
done
set -u
