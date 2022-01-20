#!/bin/sh
#
# This file has parts that are governed by one license and other parts that are governed by a second license (both apply).
# The first license is:
#   Licensed under https://github.com/EduardoRFS/reason-mobile/blob/7ba258319b87943d2eb0d8fb84562d0afeb2d41f/LICENSE#L1 - MIT License
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
# reproducible-compile-ocaml-3-build_cross.sh -d DKMLDIR -t TARGETDIR
#
# Purpose:
# 1. Optional layer on top of a host OCaml environment a cross-compiling OCaml environment using techniques pioneered by
#    @EduardoRFS:
#    a) the OCaml native libraries use the target ABI
#    b) the OCaml native compiler generates the target ABI
#    c) the OCaml compiler-library package uses the target ABI and generate the target ABI
#    d) the remainder (especially the OCaml toplevel) use the host ABI
#    See https://github.com/anmonteiro/nix-overlays/blob/79d36ea351edbaf6ee146d9bf46b09ee24ed6ece/cross/ocaml.nix for
#    reference material and an alternate way of doing it on nix.
#
# -------------------------------------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
  {
    printf "%s\n" "Usage:"
    printf "%s\n" "    reproducible-compile-ocaml-3-build_cross.sh"
    printf "%s\n" "        -h             Display this help message."
    printf "%s\n" "        -d DIR -t DIR  Compile OCaml."
    printf "\n"
    printf "%s\n" "See 'reproducible-compile-ocaml-1-setup.sh -h' for more comprehensive docs."
    printf "\n"
    printf "%s\n" "If not '-a TARGETABIS' is specified, this script does nothing"
    printf "\n"
    printf "%s\n" "Options"
    printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file"
    printf "%s\n" "   -t DIR: Target directory for the reproducible directory tree"
    printf "%s\n" "   -a TARGETABIS: Optional. See reproducible-compile-ocaml-1-setup.sh"
    printf "%s\n" "   -e DKMLHOSTABI: Uses the Diskuv OCaml compiler detector find a host ABI compiler"
    printf "%s\n" "   -i OCAMLCARGS: Optional. Extra arguments passed to ocamlc like -g to save debugging"
    printf "%s\n" "   -j OCAMLOPTARGS: Optional. Extra arguments passed to ocamlopt like -g to save debugging"
    printf "%s\n" "   -n CONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure. --with-flexdll"
    printf "%s\n" "      and --host will have already been set appropriately, but you can override the --host heuristic by adding it"
    printf "%s\n" "      to -n CONFIGUREARGS"
  } >&2
}

DKMLDIR=
TARGETDIR=
TARGETABIS=
CONFIGUREARGS=
DKMLHOSTABI=
OCAMLCARGS=
OCAMLOPTARGS=
while getopts ":d:t:a:n:e:i:j:h" opt; do
  case ${opt} in
  h)
    usage
    exit 0
    ;;
  d)
    DKMLDIR="$OPTARG"
    if [ ! -e "$DKMLDIR/.dkmlroot" ]; then
      printf "%s\n" "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2
      usage
      exit 1
    fi
    DKMLDIR=$(cd "$DKMLDIR" && pwd) # absolute path
    ;;
  t)
    TARGETDIR="$OPTARG"
    ;;
  a)
    TARGETABIS="$OPTARG"
    ;;
  n)
    CONFIGUREARGS="$OPTARG"
    ;;
  e)
    DKMLHOSTABI="$OPTARG"
    ;;
  i)
    OCAMLCARGS="$OPTARG"
    ;;
  j)
    OCAMLOPTARGS="$OPTARG"
    ;;
  \?)
    printf "%s\n" "This is not an option: -$OPTARG" >&2
    usage
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "$DKMLDIR" ] || [ -z "$TARGETDIR" ] || [ -z "$DKMLHOSTABI" ]; then
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

# Quick exit
if [ -z "$TARGETABIS" ]; then
  exit 0
fi

# ------------------
# BEGIN Target ABI OCaml
#
# Most of this section was adapted from
# https://github.com/EduardoRFS/reason-mobile/blob/7ba258319b87943d2eb0d8fb84562d0afeb2d41f/patches/ocaml/files/make.cross.sh
# and https://github.com/anmonteiro/nix-overlays/blob/79d36ea351edbaf6ee146d9bf46b09ee24ed6ece/cross/ocaml.nix
# after discussion from authors at https://discuss.ocaml.org/t/cross-compiling-implementations-how-they-work/8686 .
# Portable shell linting (shellcheck) fixes applied.

# Prereqs for reproducible-compile-ocaml-functions.sh
autodetect_system_binaries
autodetect_system_path
autodetect_cpus
autodetect_posix_shell

# shellcheck disable=SC1091
. "$DKMLDIR/vendor/dkml-component-ocamlrun/src/reproducible-compile-ocaml-functions.sh"

## Parameters

if [ -x /usr/bin/cygpath ]; then
  # Makefiles have very poor support for Windows paths, so use mixed (ex. C:/Windows) paths
  OCAMLSRC_HOST_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/src/ocaml")
else
  OCAMLSRC_HOST_MIXED="$TARGETDIR_UNIX/src/ocaml"
fi
export OCAMLSRC_HOST_MIXED

# Probe the artifacts from ./configure already done by the host ABI and host ABI's ./ocamlc
init_hostvars

make_target() {
  make_target_ABI=$1
  shift
  make_target_BUILD_ROOT=$1
  shift

  # BUILD_ROOT is passed to `ocamlrun .../ocamlmklink -o unix -oc unix -ocamlc '$(CAMLC)'`
  # in Makefile, so needs to be mixed Unix/Win32 path. Also the just mentioned example is
  # run from the Command Prompt on Windows rather than MSYS2 on Windows, so use /usr/bin/env
  # to always switch into Unix context.
  CAMLC="$HOST_SPACELESS_ENV_EXE $make_target_BUILD_ROOT/support/ocamlcTarget.wrapper" \
  CAMLOPT="$HOST_SPACELESS_ENV_EXE $make_target_BUILD_ROOT/support/ocamloptTarget.wrapper" \
  make_caml "$make_target_ABI" BUILD_ROOT="$make_target_BUILD_ROOT" "$@"
}

# Get a triplet that can be used by OCaml's ./configure.
# See https://github.com/ocaml/ocaml/blob/35af4cddfd31129391f904167236270a004037f8/configure#L14306-L14334
# for the Android triplet format.
ocaml_android_triplet() {
  ocaml_android_triplet_ABI=$1
  shift

  if [ "${DKML_COMPILE_TYPE:-}" = CM ] && [ -n "${DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET:-}" ]; then
    # Use CMAKE_C_COMPILER_TARGET=armv7-none-linux-androideabi16 (etc.)
    # Reference: https://android.googlesource.com/platform/ndk/+/master/meta/abis.json
    case "$DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET" in
    arm*-none-linux-android* | aarch64*-none-linux-android* | i686*-none-linux-android* | x86_64*-none-linux-android*)
      printf "%s\n" "$DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET"
      return
      ;;
    esac
  fi
  # Use given DKML ABI to find OCaml triplet
  case "$ocaml_android_triplet_ABI" in
    android_x86)      printf "i686-none-linux-android\n" ;;
    android_x86_64)   printf "x86_64-none-linux-android\n" ;;
    # v7a uses soft-float not hard-float (eabihf). https://developer.android.com/ndk/guides/abis#v7a
    android_arm32v7a) printf "armv7-none-linux-androideabi\n" ;;
    # v8a probably doesn't use hard-float since removed in https://android.googlesource.com/platform/ndk/+/master/docs/HardFloatAbi.md
    android_arm64v8a) printf "aarch64-none-linux-androideabi\n" ;;
    # fallback to v6 (Raspberry Pi 1, Raspberry Pi Zero). Raspberry Pi uses soft-float;
    # https://www.raspbian.org/RaspbianFAQ#What_is_Raspbian.3F . We do the same since it has most market
    # share
    *)                printf "armv5-none-linux-androideabi\n" ;;
  esac
}

build_world() {
  build_world_BUILD_ROOT=$1
  shift
  build_world_PREFIX=$1
  shift
  build_world_TARGET_ABI=$1
  shift
  build_world_PRECONFIGURE=$1
  shift

  # PREFIX is captured in `ocamlc -config` so it needs to be a mixed Unix/Win32 path.
  # BUILD_ROOT is used in `ocamlopt.opt -I ...` so it needs to be a native path or mixed Unix/Win32 path.
  if [ -x /usr/bin/cygpath ]; then
    build_world_PREFIX=$(/usr/bin/cygpath -am "$build_world_PREFIX")
    build_world_BUILD_ROOT=$(/usr/bin/cygpath -am "$build_world_BUILD_ROOT")
  fi

  case "$build_world_TARGET_ABI" in
  windows_*) build_world_TARGET_EXE_EXT=.exe ;;
  *) build_world_TARGET_EXE_EXT= ;;
  esac

  # Are we consistently Win32 host->target or consistently Unix host->target? If not we will
  # have some C functions that are missing.
  case "$DKMLHOSTABI" in
  windows_*)
    case "$build_world_TARGET_ABI" in
    windows_*) build_world_WIN32UNIX_CONSISTENT=ON ;;
    *) build_world_WIN32UNIX_CONSISTENT=OFF ;;
    esac
    ;;
  *)
    case "$build_world_TARGET_ABI" in
    windows_*) build_world_WIN32UNIX_CONSISTENT=OFF ;;
    *) build_world_WIN32UNIX_CONSISTENT=ON ;;
    esac
    ;;
  esac
  if [ "$build_world_WIN32UNIX_CONSISTENT" = OFF ]; then
    printf "FATAL: You cannot cross-compile between Windows and Unix\n"
    exit 107
  fi

  # Make C compiler script for target ABI. Any compile spec (especially from CMake) will be
  # applied.
  install -d "$build_world_BUILD_ROOT"/support
  DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_ABI="$build_world_TARGET_ABI" autodetect_compiler "$build_world_BUILD_ROOT"/support/with-target-c-compiler.sh

  # Target wrappers
  # shellcheck disable=SC2086
  log_trace genWrapper "$build_world_BUILD_ROOT/support/ocamlcTarget.wrapper" "$build_world_BUILD_ROOT"/support/with-target-c-compiler.sh "$OCAMLSRC_HOST_MIXED"/support/with-linking-on-host.sh "$build_world_BUILD_ROOT/ocamlc.opt$build_world_TARGET_EXE_EXT" $OCAMLCARGS -I "$build_world_BUILD_ROOT/stdlib" -I "$build_world_BUILD_ROOT/otherlibs/unix" -nostdlib
  # shellcheck disable=SC2086
  log_trace genWrapper "$build_world_BUILD_ROOT/support/ocamloptTarget.wrapper" "$build_world_BUILD_ROOT"/support/with-target-c-compiler.sh "$OCAMLSRC_HOST_MIXED"/support/with-linking-on-host.sh "$build_world_BUILD_ROOT/ocamlopt.opt$build_world_TARGET_EXE_EXT" $OCAMLOPTARGS -I "$build_world_BUILD_ROOT/stdlib" -I "$build_world_BUILD_ROOT/otherlibs/unix" -nostdlib

  # clean (otherwise you will 'make inconsistent assumptions' errors with a mix of host + target binaries)
  make clean

  # provide --host for use in `checking whether we are cross compiling` ./configure step
  case "$build_world_TARGET_ABI" in
  android_*)
    build_world_HOST_TRIPLET=$(ocaml_android_triplet "$build_world_TARGET_ABI")
    ;;
  *)
    # This is a fallback, just not a perfect one
    build_world_HOST_TRIPLET=$("$build_world_BUILD_ROOT"/build-aux/config.guess)
    ;;
  esac

  # ./configure
  log_trace ocaml_configure "$build_world_PREFIX" "$build_world_TARGET_ABI" "$build_world_PRECONFIGURE" "--host=$build_world_HOST_TRIPLET $CONFIGUREARGS --disable-ocamldoc"

  # Build
  # -----

  # Make non-boot ./ocamlc and ./ocamlopt compiler
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_host -final flexdll
  fi
  log_trace make_host -final runtime coreall
  log_trace make_host -final opt-core
  log_trace make_host -final ocamlc.opt NATIVECCLIBS= BYTECCLIBS= # host and target C libraries don't mix
  #   Troubleshooting
  {
    printf "+ '%s/ocamlc.opt' -config\n" "$build_world_BUILD_ROOT" >&2
    "$build_world_BUILD_ROOT"/ocamlc.opt -config >&2
  }
  log_trace make_host -final ocamlopt.opt

  # Tools we want that we can compile using the OCaml compiler to run on the host.
  log_trace make_host -final ocaml ocamldebugger ocamllex.opt ocamltoolsopt
  
  # Tools we don't need but are needed by `install` target
  log_trace make_host -final expunge

  # Remove all OCaml compiled modules since they were compiled with boot/ocamlc
  remove_compiled_objects_from_curdir

  # Recompile stdlib (and flexdll if enabled)
  #   See notes in 2-build_host.sh for why we compile twice.
  #   (We have to serialize the make_ commands because OCaml Makefile do not usually build multiple targets in parallel)
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_host -compile-stdlib flexdll
  fi
  printf "+ INFO: Compiling host stdlib in pass 1\n" >&2
  log_trace make_host -final  -C stdlib all allopt
  printf "+ INFO: Recompiling host ocamlc in pass 1\n" >&2
  log_trace make_host -final  ocamlc
  printf "+ INFO: Recompiling host ocamlopt in pass 1\n" >&2
  log_trace make_host -final  ocamlopt
  printf "+ INFO: Recompiling host ocamlc.opt/ocamlopt.opt in pass 1\n" >&2
  log_trace make_host -final  ocamlc.opt ocamlopt.opt
  printf "+ INFO: Recompiling host stdlib in pass 2\n" >&2
  log_trace make_host -final  -C stdlib all allopt

  # Remove all OCaml compiled modules since they were compiled for the host ABI
  remove_compiled_objects_from_curdir

  # ------------------------------------------------------------------------------------
  # From this point on we do _not_ build {ocamlc,ocamlopt,*}.opt native code executables
  # because they have to run on the host. We already built those! They have all the
  # settings from ./configure which is tuned for the target ABI.
  # vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

  # Recompile stdlib (and flexdll if enabled)
  #   See notes in 2-build_host.sh for why we compile twice
  #   (We have to serialize the make_ commands because OCaml Makefile do not usually build multiple targets in parallel)
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" flexdll
  fi
  printf "+ INFO: Compiling target stdlib in pass 1\n" >&2
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" -C stdlib all allopt
  printf "+ INFO: Recompiling target ocaml in pass 1\n" >&2
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" ocaml
  printf "+ INFO: Recompiling target ocamlc in pass 1\n" >&2
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" ocamlc
  printf "+ INFO: Recompiling target ocamlopt in pass 1\n" >&2
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" ocamlopt
  printf "+ INFO: Recompiling target stdlib in pass 2\n" >&2
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" -C stdlib all allopt
  log_trace "$DKMLSYS_CHMOD" -R 500 stdlib/

  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" otherlibraries
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" otherlibrariesopt
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" ocamltoolsopt
  #   stop warning about native binary older than bytecode binary
  log_trace touch "lex/ocamllex.opt${build_world_TARGET_EXE_EXT}"
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" driver/main.cmx driver/optmain.cmx \
    compilerlibs/ocamlcommon.cmxa \
    compilerlibs/ocamlbytecomp.cmxa \
    compilerlibs/ocamloptcomp.cmxa

  ## Install
  "$DKMLSYS_INSTALL" -v -d "$build_world_PREFIX/bin" "$build_world_PREFIX/lib/ocaml"
  "$DKMLSYS_INSTALL" -v "runtime/ocamlrun$build_world_TARGET_EXE_EXT" "$build_world_PREFIX/bin/"
  log_trace make_host -final install
  log_trace make_host -final -C debugger install
  "$DKMLSYS_INSTALL" -v "$OCAMLSRC_HOST_MIXED/runtime/ocamlrund" "$OCAMLSRC_HOST_MIXED/runtime/ocamlruni" "$build_world_PREFIX/bin/"
  "$DKMLSYS_INSTALL" -v "$OCAMLSRC_HOST_MIXED/yacc/ocamlyacc" "$build_world_PREFIX/bin/"
}

# Loop over each target abi script file; each file separated by semicolons, and each term with an equals
printf "%s\n" "$TARGETABIS" | sed 's/;/\n/g' | sed 's/^\s*//; s/\s*$//' > "$WORK"/target-abis
log_script "$WORK"/target-abis
while IFS= read -r _abientry; do
  _targetabi=$(printf "%s" "$_abientry" | sed 's/=.*//')
  _abiscript=$(printf "%s" "$_abientry" | sed 's/^[^=]*=//')

  case "$_abiscript" in
  /* | ?:*) # /a/b/c or C:\Windows
    ;;
  *) # relative path; need absolute path since we will soon change dir to $_CROSS_SRCDIR
    _abiscript="$DKMLDIR/$_abiscript"
    ;;
  esac

  _CROSS_TARGETDIR=$TARGETDIR_UNIX/opt/mlcross/$_targetabi
  _CROSS_SRCDIR=$_CROSS_TARGETDIR/src/ocaml
  cd "$_CROSS_SRCDIR"
  build_world "$_CROSS_SRCDIR" "$_CROSS_TARGETDIR" "$_targetabi" "$_abiscript"
done <"$WORK"/target-abis
