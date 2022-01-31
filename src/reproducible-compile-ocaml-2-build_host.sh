#!/bin/sh
#
# This file has parts that are governed by one license and other parts that are governed by a second license (both apply).
# The first license is:
#   Licensed under https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/LICENSE - LGPL 2.1 with special linking exceptions
# The second license (Apache License, Version 2.0) is below.
#
# ----------------------------
# Copyright 2021 Diskuv, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------
#
# @jonahbeckford: 2021-10-26
# - This file is licensed differently than the rest of the Diskuv OCaml distribution.
#   Keep the Apache License in this file since this file is part of the reproducible
#   build files.
#
######################################
# reproducible-compile-ocaml-2-build_host.sh -d DKMLDIR -t TARGETDIR
#
# Purpose:
# 1. Build an OCaml environment including an OCaml native compiler that generates machine code for the
#    host ABI. Much of that follows
#    https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/shell/bootstrap-ocaml.sh,
#    especially the Windows knobs.
#
# -------------------------------------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
    {
        printf "%s\n" "Usage:"
        printf "%s\n" "    reproducible-compile-ocaml-2-build_host.sh"
        printf "%s\n" "        -h             Display this help message."
        printf "%s\n" "        -d DIR -t DIR  Compile OCaml."
        printf "\n"
        printf "%s\n" "See 'reproducible-compile-ocaml-1-setup.sh -h' for more comprehensive docs."
        printf "\n"
        printf "%s\n" "Options"
        printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file"
        printf "%s\n" "   -t DIR: Target directory for the reproducible directory tree"
        printf "%s\n" "   -b PREF: Required and used only for the MSVC compiler. See reproducible-compile-ocaml-1-setup.sh"
        printf "%s\n" "   -e DKMLHOSTABI: Uses the Diskuv OCaml compiler detector find a host ABI compiler"
        printf "%s\n" "   -f HOSTSRC_SUBDIR: Use HOSTSRC_SUBDIR subdirectory of -t DIR to place the source code of the host ABI"
        printf "%s\n" "   -i OCAMLCARGS: Optional. Extra arguments passed to ocamlc like -g to save debugging"
        printf "%s\n" "   -j OCAMLOPTARGS: Optional. Extra arguments passed to ocamlopt like -g to save debugging"
        printf "%s\n" "   -k HOSTABISCRIPT: Optional. See reproducible-compile-ocaml-1-setup.sh"
        printf "%s\n" "   -m CONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure. --with-flexdll"
        printf "%s\n" "      and --host will have already been set appropriately, but you can override the --host heuristic by adding it"
        printf "%s\n" "      to -m CONFIGUREARGS"
        printf "%s\n" "   -r Only build ocamlrun, Stdlib and the other libraries. Cannot be used with -a TARGETABIS"
    } >&2
}

DKMLDIR=
TARGETDIR=
DKMLHOSTABI=
CONFIGUREARGS=
OCAMLCARGS=
OCAMLOPTARGS=
HOSTABISCRIPT=
RUNTIMEONLY=OFF
HOSTSRC_SUBDIR=
export MSVS_PREFERENCE=
while getopts ":d:t:b:e:m:i:j:k:rf:h" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        d )
            DKMLDIR="$OPTARG"
            if [ ! -e "$DKMLDIR/.dkmlroot" ]; then
                printf "%s\n" "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2;
                usage
                exit 1
            fi
            DKMLDIR=$(cd "$DKMLDIR" && pwd) # absolute path
        ;;
        t )
            TARGETDIR="$OPTARG"
        ;;
        b )
            MSVS_PREFERENCE="$OPTARG"
        ;;
        e )
            DKMLHOSTABI="$OPTARG"
        ;;
        f ) HOSTSRC_SUBDIR=$OPTARG ;;
        m )
            CONFIGUREARGS="$OPTARG"
        ;;
        i)
            OCAMLCARGS="$OPTARG"
            ;;
        j)
            OCAMLOPTARGS="$OPTARG"
            ;;
        k)
            HOSTABISCRIPT="$OPTARG"
            ;;
        r)
            RUNTIMEONLY=ON
            ;;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$DKMLDIR" ] || [ -z "$TARGETDIR" ] || [ -z "$DKMLHOSTABI" ] || [ -z "$HOSTSRC_SUBDIR" ]; then
    printf "%s\n" "Missing required options" >&2
    usage
    exit 1
fi

# END Command line processing
# ------------------

# Need feature flag and usermode and statedir until all legacy code is removed in _common_tool.sh
# shellcheck disable=SC2034
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON
# shellcheck disable=SC2034
USERMODE=ON
# shellcheck disable=SC2034
STATEDIR=

# shellcheck disable=SC1091
. "$DKMLDIR/vendor/dkml-runtime-common/unix/_common_tool.sh"

disambiguate_filesystem_paths

# Bootstrapping vars
TARGETDIR_UNIX=$(cd "$TARGETDIR" && pwd) # better than cygpath: handles TARGETDIR=. without trailing slash, and works on Unix/Windows
if [ -x /usr/bin/cygpath ]; then
    OCAMLSRC_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/$HOSTSRC_SUBDIR")
    OCAMLSRC_HOST=$(/usr/bin/cygpath -aw "$TARGETDIR_UNIX/$HOSTSRC_SUBDIR")
    # Makefiles have very poor support for Windows paths, so use mixed (ex. C:/Windows) paths
    OCAMLSRC_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/$HOSTSRC_SUBDIR")
else
    OCAMLSRC_UNIX="$TARGETDIR_UNIX/$HOSTSRC_SUBDIR"
    OCAMLSRC_HOST="$TARGETDIR_UNIX/$HOSTSRC_SUBDIR"
    OCAMLSRC_MIXED="$TARGETDIR_UNIX/$HOSTSRC_SUBDIR"
fi
export OCAMLSRC_MIXED

# ------------------

# Prereqs for reproducible-compile-ocaml-functions.sh
autodetect_system_binaries
autodetect_system_path
autodetect_cpus
autodetect_posix_shell

# shellcheck disable=SC1091
. "$DKMLDIR/vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-functions.sh"

if [ -n "$HOSTABISCRIPT" ]; then
    case "$HOSTABISCRIPT" in
    /* | ?:*) # /a/b/c or C:\Windows
    ;;
    *) # relative path; need absolute path since we will soon change dir to $OCAMLSRC_UNIX
    HOSTABISCRIPT="$DKMLDIR/$HOSTABISCRIPT"
    ;;
    esac
fi

cd "$OCAMLSRC_UNIX"

# Dump environment variables
if [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ] ; then
    printf '@+ build_host env\n' >&2
    "$DKMLSYS_ENV" | "$DKMLSYS_SED" 's/^/@env+| /' | "$DKMLSYS_AWK" '{print}' >&2
    printf '@env?| DKML_COMPILE_SPEC=%s\n' "${DKML_COMPILE_SPEC:-}" >&2
    printf '@env?| DKML_COMPILE_TYPE=%s\n' "${DKML_COMPILE_TYPE:-}" >&2
fi

# Make C compiler script for host ABI. Allow passthrough of C compiler from caller, otherwise
# use the system (SYS) compiler.
install -d "$OCAMLSRC_MIXED"/support
HOST_DKML_COMPILE_SPEC=${DKML_COMPILE_SPEC:-1}
HOST_DKML_COMPILE_TYPE=${DKML_COMPILE_TYPE:-SYS}
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_ABI="$DKMLHOSTABI" DKML_COMPILE_SPEC=$HOST_DKML_COMPILE_SPEC DKML_COMPILE_TYPE=$HOST_DKML_COMPILE_TYPE autodetect_compiler "$OCAMLSRC_MIXED"/support/with-host-c-compiler.sh

# ./configure
if [ "$RUNTIMEONLY" = ON ]; then
    CONFIGUREARGS="$CONFIGUREARGS --disable-native-compiler --disable-stdlib-manpages"
fi
log_trace ocaml_configure "$TARGETDIR_UNIX" "$DKMLHOSTABI" "$HOSTABISCRIPT" "$CONFIGUREARGS"

# fix readonly perms we'll set later (if we've re-used the files because
# of a cache)
log_trace "$DKMLSYS_CHMOD" -R ug+w      stdlib/

# Make non-boot ./ocamlc and ./ocamlopt compiler
if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    #   trigger `flexlink` target, especially its making of boot/ocamlrun.exe
    log_trace touch flexdll/Makefile
    log_trace rm -f flexdll/flexlink.exe
    log_trace ocaml_make "$DKMLHOSTABI" flexdll
fi
log_trace ocaml_make "$DKMLHOSTABI"     coldstart
log_trace ocaml_make "$DKMLHOSTABI"     coreall            # Also produces ./ocaml
if [ "$RUNTIMEONLY" = ON ]; then
    log_trace install -d "$TARGETDIR_UNIX/bin" "$TARGETDIR_UNIX/lib/ocaml"
    log_trace ocaml_make "$DKMLHOSTABI" -C runtime install
    log_trace ocaml_make "$DKMLHOSTABI" -C stdlib install
    log_trace ocaml_make "$DKMLHOSTABI" otherlibraries    
    # shellcheck disable=SC2016
    OTHERLIBRARIES=$($DKMLSYS_AWK 'BEGIN{FS="="} $1=="OTHERLIBRARIES"{print $2}' Makefile.config)
    for otherlibrary in ${OTHERLIBRARIES}; do
        ocaml_make "$DKMLHOSTABI"       -C otherlibs/"$otherlibrary" install
    done
    # Finished the runtime parts
    exit 0
fi
log_trace ocaml_make "$DKMLHOSTABI" opt-core
log_trace ocaml_make "$DKMLHOSTABI" ocamlc.opt
#   Generated ./ocamlc for some reason has a shebang reference to the bin/ocamlrun install
#   location. So install the runtime.
log_trace install -d "$TARGETDIR_UNIX/bin" "$TARGETDIR_UNIX/lib/ocaml"
log_trace ocaml_make "$DKMLHOSTABI"     -C runtime install
log_trace ocaml_make "$DKMLHOSTABI"     ocamlopt.opt       # Can use ./ocamlc (depends on exact sequence above; doesn't now though)

# Probe the artifacts from ./configure + ./ocamlc
init_hostvars

# Make script to set OCAML_FLEXLINK so flexlink.exe and run correctly on Windows, and other
# environment variables needed to link OCaml bytecode or native code on the host.
#
#   We have a bad flexlink situation on Windows. flexlink.exe will either be a
#   native executable or a bytecode executable; when it is a native executable
#   it will segfault if it is not installed in the right file location (you
#   can't run it from flexdll/flexlink.exe); when it is a bytecode executable
#   you need to run it with ocamlrun (unlike Unix which interpret the
#   shebang to ocamlrun).
#   So on Windows ...
#   1. We consistently use the ocamlrun bytecode form of flexlink.exe
#   2. We only make the native code flexlink.exe as the very last step (when
#      it can't be used for linking other executables)
if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    # OCAML_FLEXLINK is expected to be a bytecode executable

    #   Since OCAML_FLEXLINK does not support spaces like in
    #   C:\Users\John Doe\flexdll
    #   we make a single script for `*/boot/ocamlrun */flexdll/flexlink.exe`
    {
        printf "#!%s\n" "$DKML_POSIX_SHELL"
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 4 ] ; then
            printf "exec '%s/boot/ocamlrun' '%s' -v -v \"\$@\"\n" "$OCAMLSRC_UNIX" "$OCAMLSRC_HOST"'\flexdll\flexlink.exe'
        elif [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ] ; then
            printf "exec '%s/boot/ocamlrun' '%s' -v \"\$@\"\n" "$OCAMLSRC_UNIX" "$OCAMLSRC_HOST"'\flexdll\flexlink.exe'
        else
            printf "exec '%s/boot/ocamlrun' '%s' \"\$@\"\n" "$OCAMLSRC_UNIX" "$OCAMLSRC_HOST"'\flexdll\flexlink.exe'
        fi
    } >"$OCAMLSRC_UNIX"/support/ocamlrun-flexlink.sh.tmp
    $DKMLSYS_CHMOD +x "$OCAMLSRC_UNIX"/support/ocamlrun-flexlink.sh.tmp
    $DKMLSYS_MV "$OCAMLSRC_UNIX"/support/ocamlrun-flexlink.sh.tmp "$OCAMLSRC_UNIX"/support/ocamlrun-flexlink.sh
    log_script "$OCAMLSRC_UNIX"/support/ocamlrun-flexlink.sh

    #   Then we call it using env.exe since ocamlrun-flexlink.sh can be called from
    #   a Command Prompt context.
    {
        printf "#!%s\n" "$DKML_POSIX_SHELL"
        printf "export OCAML_FLEXLINK='%s %s/support/ocamlrun-flexlink.sh'\n" "$HOST_SPACELESS_ENV_MIXED_EXE" "$OCAMLSRC_MIXED"
        printf "exec \"\$@\"\n"
    } >"$OCAMLSRC_UNIX"/support/with-linking-on-host.sh.tmp
else
    printf "#!%s\nexec \"\$@\"\n" "$DKML_POSIX_SHELL" >"$OCAMLSRC_UNIX"/support/with-linking-on-host.sh.tmp
fi
$DKMLSYS_CHMOD +x "$OCAMLSRC_UNIX"/support/with-linking-on-host.sh.tmp
$DKMLSYS_MV "$OCAMLSRC_UNIX"/support/with-linking-on-host.sh.tmp "$OCAMLSRC_UNIX"/support/with-linking-on-host.sh
log_script "$OCAMLSRC_UNIX"/support/with-linking-on-host.sh

# Host wrappers
#   Technically the wrappers are not needed. However, the cross-compiling part needs to have the exact same host compiler
#   settings we use here, so the wrappers are what we want. Actually, just let the cross compiling part re-use the same
#   host wrapper.
create_ocamlc_wrapper() {
    create_ocamlc_wrapper_PASS=$1 ; shift
    # shellcheck disable=SC2086
    log_trace genWrapper "$OCAMLSRC_MIXED/support/ocamlcHost$create_ocamlc_wrapper_PASS.wrapper"     "$OCAMLSRC_MIXED"/support/with-host-c-compiler.sh "$OCAMLSRC_MIXED"/support/with-linking-on-host.sh "$OCAMLSRC_MIXED/ocamlc.opt$HOST_EXE_EXT" $OCAMLCARGS "$@"
}
create_ocamlopt_wrapper() {
    create_ocamlopt_wrapper_PASS=$1 ; shift
    # shellcheck disable=SC2086
    log_trace genWrapper "$OCAMLSRC_MIXED/support/ocamloptHost$create_ocamlopt_wrapper_PASS.wrapper" "$OCAMLSRC_MIXED"/support/with-host-c-compiler.sh "$OCAMLSRC_MIXED"/support/with-linking-on-host.sh "$OCAMLSRC_MIXED/ocamlopt.opt$HOST_EXE_EXT" $OCAMLOPTARGS "$@"
}
create_ocamlrun_ocamlopt_wrapper() {
    create_ocamlrun_ocamlopt_wrapper_PASS=$1 ; shift
    # shellcheck disable=SC2086
    log_trace genWrapper "$OCAMLSRC_MIXED/support/ocamloptHost$create_ocamlrun_ocamlopt_wrapper_PASS.wrapper" "$OCAMLSRC_MIXED"/support/with-host-c-compiler.sh "$OCAMLSRC_MIXED"/support/with-linking-on-host.sh "$OCAMLSRC_MIXED/runtime/ocamlrun$HOST_EXE_EXT" "$OCAMLSRC_MIXED/ocamlopt$HOST_EXE_EXT" $OCAMLOPTARGS "$@"
}
#   Since the Makefile is sensitive to timestamps, we must make sure the wrappers have timestamps
#   before any generated code (or else it will recompile).
create_ocamlc_wrapper               -compile-stdlib
create_ocamlopt_wrapper             -compile-stdlib
case "$DKMLHOSTABI" in
    windows_*)
        _unix_include="$OCAMLSRC_MIXED${HOST_DIRSEP}otherlibs${HOST_DIRSEP}win32unix"
        ;;
    *)
        _unix_include="$OCAMLSRC_MIXED${HOST_DIRSEP}otherlibs${HOST_DIRSEP}unix"
        ;;
esac
create_ocamlc_wrapper               -compile-ocamlopt   -I "$OCAMLSRC_MIXED${HOST_DIRSEP}stdlib" -I "$_unix_include" -nostdlib
create_ocamlrun_ocamlopt_wrapper    -compile-ocamlopt   -I "$OCAMLSRC_MIXED${HOST_DIRSEP}stdlib" -I "$_unix_include" -nostdlib
create_ocamlc_wrapper               -final              -I "$OCAMLSRC_MIXED${HOST_DIRSEP}stdlib" -I "$_unix_include" -nostdlib
create_ocamlopt_wrapper             -final              -I "$OCAMLSRC_MIXED${HOST_DIRSEP}stdlib" -I "$_unix_include" -nostdlib

# Remove all OCaml compiled modules since they were compiled with boot/ocamlc
#   We do not want _any_ `make inconsistent assumptions over interface Stdlib__format` during cross-compilation.
#   Technically if all we wanted was the host OCaml system, we don't need to remove all OCaml compiled modules; its `make world` has that intelligence.
#   Exclude the testsuite which has checked-in .cmm files, and exclude .cmd files.
remove_compiled_objects_from_curdir

# Recompile stdlib (and flexdll if enabled)
printf "+ INFO: Compiling stdlib in pass 1\n" >&2
log_trace make_host -compile-stdlib     -C stdlib all
log_trace make_host -compile-stdlib     -C stdlib allopt
#   Any future Makefile target that uses ./ocamlc will try to recompile it because it depends
#   on compilerlibs/ocamlcommon.cma (and other .cma files). And that will trigger a new
#   recompilation of stdlib. So we have to recompile them both until no more surprise
#   recompilations of stdlib (creating `make inconsistent assumptions`).
printf "+ INFO: Recompiling ocamlc in pass 1\n" >&2
log_trace make_host -final              ocamlc
printf "+ INFO: Recompiling ocamlopt in pass 1\n" >&2
log_trace make_host -final              ocamlopt
printf "+ INFO: Recompiling ocamlc.opt in pass 1\n" >&2
log_trace make_host -final              ocamlc.opt
printf "+ INFO: Recompiling ocamlopt.opt in pass 1\n" >&2
#   Since `make_host -final` uses ocamlopt.opt we should not (and cannot on Windows)
#   overwrite the executable which is producing the executable (even if it works on some OS).
#   So run the bytecode ocamlopt executable to produce the native code ocamlopt.opt
log_trace make_host -compile-ocamlopt    ocamlopt.opt
printf "+ INFO: Recompiling stdlib in pass 2\n" >&2
log_trace make_host -compile-stdlib     -C stdlib all
log_trace make_host -compile-stdlib     -C stdlib allopt
#   Bad things will happen if a subsequent make target like `all` recompiles
#   stdlib. Stdlib should be 100% stabilized at this point. If it is not
#   stabilized, we will get `make inconsistent assumptions` later and it
#   will be tricky to understand where they are coming from.
#
#   Mitigation: Changing permissions to 500 (rx-------) will hopefully cause
#   Permission Denied immediately at exact location where stdlib is being
#   rebuilt. If we've done our job right in this section, stdlib will not
#   be rebuilt at all.
log_trace "$DKMLSYS_CHMOD" -R 500       stdlib/

# Use new compiler to rebuild, with the exact same wrapper that can be used if cross-compiling
if [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 3 ] ; then
    # The `make -d` debug option will show the reason why stdlib (or anything else)
    # is being rebuilt.
    log_trace make_host -final          all -d
else
    log_trace make_host -final          all
fi
log_trace make_host -final              "${BOOTSTRAP_OPT_TARGET:-opt.opt}"

# flexlink.opt _must_ be the last thing built. See discussion near the
# beginning about "bad flexlink situation on Windows".
if [ "${OCAML_BYTECODE_ONLY:-OFF}" = OFF ] && [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace ocaml_make "$DKMLHOSTABI" flexlink.opt
fi

# Install
log_trace "$DKMLSYS_CHMOD" -R ug+w      stdlib/ # Restore file permissions
log_trace make_host -final              install

# Test executables that they were properly linked
if [ "${OCAML_BYTECODE_ONLY:-OFF}" = OFF ] && [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace "$TARGETDIR_UNIX"/bin/flexlink.exe --help >&2
fi
log_trace "$TARGETDIR_UNIX"/bin/ocamlc -config >&2
log_trace "$TARGETDIR_UNIX"/bin/ocamlopt -config >&2
log_trace "$TARGETDIR_UNIX"/bin/ocamlc.opt -config >&2
log_trace "$TARGETDIR_UNIX"/bin/ocamlopt.opt -config >&2
