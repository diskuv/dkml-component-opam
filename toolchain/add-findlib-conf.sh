#!/bin/bash
# Idempotent addition of mlcross compilers as toolchains in findlib.conf
#
# Usage: add-findlib-config.sh HOSTLIB_DIR MLCROSS_DIR
#
# HOSTLIB_DIR is the lib/ directory for the host ABI that contains
# `findlib.conf` among others.
#
# The generated findlib configuration file will be
# <HOSTLIB_DIR>/findlib.conf.d/<toolchain>.conf for compatibility
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
# path(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/lib:<HOSTLIB_DIR>"
#   The META/package search path will start in the cross-compiled lib folder.
#   There are no META packages in the cross-compiled folder initially,
#   so all packages like `threads/META` will be located in `<HOSTLIB_DIR>`.
#   However newly installed packages will be added by the `destdir`
#   directive so the cross-compiled folder may receive META files.
# stdlib(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/lib"
#   Built-in package libraries like `threads.cmxa` can be located
#   in `<MLCROSS_DIR>/<dkmlabi>/lib/``.
# destdir(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/lib"
#   Newly cross-compiled packages will be added to this `destdir`. Typically
#   you build but do not install cross-compiled packages, so this may have
#   little use
# ocamlc(<dkmlabi>) = "<MLCROSS_DIR>/<dkmlabi>/bin/ocamlc.opt"
#   The cross-compiler ocamlc. Other binaries (ex. ocamlopt) are added as well.
#   Some binaries may be bytecode executables while some may be native
#   executables.

set -euf

HOSTLIB_DIR=$1
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
    findlib_conf="$HOSTLIB_DIR/findlib.conf.d/$dkmlabi.conf"

    # Ex. path(android_arm32v7a)="C:\\source\\windows_x86_64\\lib"
    # Any backslashes need to be escaped since it is an OCaml string
    bin_buildhost="$_crossdir/bin"
    lib_buildhost="$_crossdir/lib"
    libhost_buildhost="$HOSTLIB_DIR"
    _dirsep="/"
    _findsep=":"
    _exe=""
    if [ -x /usr/bin/cygpath ]; then
        bin_buildhost=$(/usr/bin/cygpath -aw "$bin_buildhost")
        lib_buildhost=$(/usr/bin/cygpath -aw "$lib_buildhost")
        libhost_buildhost=$(/usr/bin/cygpath -aw "$libhost_buildhost")
        _dirsep="\\\\"
        _exe=".exe"
        _findsep=";"
    elif [ -x /usr/bin/realpath ]; then
        bin_buildhost=$(/usr/bin/realpath "$bin_buildhost")
        lib_buildhost=$(/usr/bin/realpath "$lib_buildhost")
        libhost_buildhost=$(/usr/bin/realpath "$libhost_buildhost")
    fi
    bin_buildhost=$(_escape_arg_as_ocaml_string "$bin_buildhost")
    lib_buildhost=$(_escape_arg_as_ocaml_string "$lib_buildhost")

    add_if_missing "$findlib_conf" "^path($dkmlabi)"            "path($dkmlabi) = \"$lib_buildhost${_findsep}$libhost_buildhost\""
    add_if_missing "$findlib_conf" "^destdir($dkmlabi)"         "destdir($dkmlabi) = \"$lib_buildhost\""
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
