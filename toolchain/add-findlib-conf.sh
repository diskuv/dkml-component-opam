#!/bin/bash
# Idempotent addition of mlcross compilers as toolchains in findlib.conf
#
# Usage: add-findlib-config.sh PREFIX_DIR MLCROSS_DIR
#
# PREFIX_DIR is the Opam switch prefix directory that contains
# `lib/findlib.conf` among others.
#
# The generated findlib configuration file will be
# <PREFIX_DIR>/lib/findlib.conf.d/<toolchain>.conf for compatibility
# with Dune's `dune -x` option. The generation is mostly idempotent
# since, if the file already exsts, entries are only added to FINDLIB_CONF.
#
# MLCROSS_DIR is the base directory for zero or more target DKML ABIs (ex.
# android_arm32v7a) that contains bin/ and lib/ subfolders (ex.
# android_arm32v7a/bin). It can be an environment variable, but a default value
# must still be specified on the command line.
#
# findlib.conf on output
# ----------------------
#
# path(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/lib:<PREFIX_DIR>/<dkmlabi>-sysroot/lib"
#   The META/package search path will start in the cross-compiled lib folder.
#   There are no META packages in the cross-compiled folder today, but that may change.
#   Opam installs packages into <PREFIX_DIR>/<dkmlabi>-sysroot/; precisely `dune -x`
#   creates a <package>.install file containing that path, and the Opam install step
#   runs those instructions.
#   Finally, there are base packages like `threads/META` that come from ocamlfind's
#   `make install-meta`. Use an Opam module like
#   https://github.com/ocaml/opam-repository/blob/master/packages/ocamlfind-secondary/ocamlfind-secondary.1.9.1/opam
#   to install those into <PREFIX_DIR>/<dkmlabi>-sysroot/lib.
# stdlib(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/lib"
#   Built-in package libraries like `threads.cmxa` can be located
#   in `<MLCROSS_DIR>/<dkmlabi>/lib/``.
# destdir(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/lib"
#   Newly cross-compiled packages will be added to this `destdir`
# ocamlc(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/bin/ocamlc.opt"
#   The cross-compiler ocamlc. Other binaries (ex. ocamlopt) are added as well.
#   Some binaries may be bytecode executables while some may be native
#   executables.

set -euf

PREFIX_DIR=$1
shift
if [ -z "${MLCROSS_DIR:-}" ]; then
    MLCROSS_DIR=$1
fi
shift

# [add_if_missing FILE SEARCH TEXT_IF_MISSING]
add_if_missing() {
  add_if_missing_FILE=$1
  shift
  add_if_missing_SEARCH=$1
  shift
  add_if_missing_TEXT_IF_MISSING=$1
  shift
  if grep -q "$add_if_missing_SEARCH" "$add_if_missing_FILE"; then
    return 0
  fi
  printf "%s\n" "$add_if_missing_TEXT_IF_MISSING" >> "$add_if_missing_FILE"
}

# near clone of crossplatform-function.sh escape_arg_as_ocaml_string
_escape_arg_as_ocaml_string() {
    _escape_arg_as_ocaml_string_ARG=$1
    shift
    printf "%s" "$_escape_arg_as_ocaml_string_ARG" | PATH=/usr/bin:/bin sed 's#\\#\\\\#g; s#"#\\"#g;'
}

# Bash 3.x+ reading of lines into array
CROSSES=()
while IFS='' read -r line; do CROSSES+=("$line"); done < <(find "$MLCROSS_DIR" -mindepth 1 -maxdepth 1)

set +u # Fix bash bug with empty arrays
for _crossdir in "${CROSSES[@]}"; do
    # ex. android_arm32v7a
    dkmlabi=$(basename "$_crossdir")
    findlib_conf="$PREFIX_DIR/lib/findlib.conf.d/$dkmlabi.conf"

    # Ex. path(android_arm32v7a)="C:\\source\\windows_x86_64\\lib"
    # Any backslashes need to be escaped since it is an OCaml string
    bin_buildhost="$_crossdir/bin"
    lib_buildhost="$_crossdir/lib"
    sysroot_lib_buildhost="$PREFIX_DIR/$dkmlabi-sysroot/lib"
    _dirsep="/"
    _findsep=":"
    _exe=""
    if [ -x /usr/bin/cygpath ]; then
        bin_buildhost=$(/usr/bin/cygpath -aw "$bin_buildhost")
        lib_buildhost=$(/usr/bin/cygpath -aw "$lib_buildhost")
        sysroot_lib_buildhost=$(/usr/bin/cygpath -aw "$sysroot_lib_buildhost")
        _dirsep="\\\\"
        _exe=".exe"
        _findsep=";"
    elif [ -x /usr/bin/realpath ]; then
        bin_buildhost=$(/usr/bin/realpath "$bin_buildhost")
        lib_buildhost=$(/usr/bin/realpath "$lib_buildhost")
        sysroot_lib_buildhost=$(/usr/bin/realpath "$sysroot_lib_buildhost")
    fi
    bin_buildhost=$(_escape_arg_as_ocaml_string "$bin_buildhost")
    lib_buildhost=$(_escape_arg_as_ocaml_string "$lib_buildhost")

    add_if_missing "$findlib_conf" "^path($dkmlabi)"            "path($dkmlabi) = \"$lib_buildhost${_findsep}$sysroot_lib_buildhost\""
    add_if_missing "$findlib_conf" "^destdir($dkmlabi)"         "destdir($dkmlabi) = \"$sysroot_lib_buildhost\""
    add_if_missing "$findlib_conf" "^stdlib($dkmlabi)"          "stdlib($dkmlabi) = \"$lib_buildhost${_dirsep}ocaml\""
    if [ -e "$_crossdir/bin/flexlink.exe" ]; then
        add_if_missing "$findlib_conf" "^flexlink($dkmlabi)"    "flexlink($dkmlabi) = \"$bin_buildhost${_dirsep}flexlink.exe\""
    fi
    add_if_missing "$findlib_conf" "^ocaml($dkmlabi)"           "ocaml($dkmlabi) = \"$bin_buildhost${_dirsep}ocaml${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlc($dkmlabi)"          "ocamlc($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlc.opt${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlcmt($dkmlabi)"        "ocamlcmt($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlcmt${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlcp($dkmlabi)"         "ocamlcp($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlcp.byte${_exe}\""
    add_if_missing "$findlib_conf" "^ocamldebug($dkmlabi)"      "ocamldebug($dkmlabi) = \"$bin_buildhost${_dirsep}ocamldebug${_exe}\""
    add_if_missing "$findlib_conf" "^ocamldep($dkmlabi)"        "ocamldep($dkmlabi) = \"$bin_buildhost${_dirsep}ocamldep.byte${_exe}\""
    add_if_missing "$findlib_conf" "^ocamllex($dkmlabi)"        "ocamllex($dkmlabi) = \"$bin_buildhost${_dirsep}ocamllex.opt${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlmklib($dkmlabi)"      "ocamlmklib($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlmklib.byte${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlmktop($dkmlabi)"      "ocamlmktop($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlmktop.byte${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlobjinfo($dkmlabi)"    "ocamlobjinfo($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlobjinfo.byte${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlopt($dkmlabi)"        "ocamlopt($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlopt.opt${_exe}\""
    add_if_missing "$findlib_conf" "^ocamloptp($dkmlabi)"       "ocamloptp($dkmlabi) = \"$bin_buildhost${_dirsep}ocamloptp.byte${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlprof($dkmlabi)"       "ocamlprof($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlprof.byte${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlrun($dkmlabi)"        "ocamlrun($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlrun${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlrund($dkmlabi)"       "ocamlrund($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlrund${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlruni($dkmlabi)"       "ocamlruni($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlruni${_exe}\""
    add_if_missing "$findlib_conf" "^ocamlyacc($dkmlabi)"       "ocamlyacc($dkmlabi) = \"$bin_buildhost${_dirsep}ocamlyacc${_exe}\""
done
set -u
