#!/usr/bin/env bash
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
# reproducible-compile-ocaml-1-setup.sh -d DKMLDIR -t TARGETDIR \
#      -v COMMIT [-a TARGETABIS]
#
# Sets up the source code for a reproducible compilation of OCaml

set -euf

# ------------------
# BEGIN Command line processing

# Since installtime/windows/Machine/Machine.psm1 has minimum VS14 we only select that version
# or greater. We'll ignore '10.0' (Windows SDK 10) which may bundle Visual Studio 2015, 2017 or 2019.
# Also we do _not_ use the environment (ie. no '@' in MSVS_PREFERENCE) since that isn't reproducible,
# and also because it sets MSVS_* variables to empty if it thinks the environment is correct (but we
# _always_ want MSVS_* set since OCaml ./configure script branches on MSVS_* being non-empty).
OPT_MSVS_PREFERENCE='VS16.*;VS15.*;VS14.0' # KEEP IN SYNC with 2-build.sh

usage() {
    {
        printf "%s\n" "Usage:"
        printf "%s\n" "    reproducible-compile-ocaml-1-setup.sh"
        printf "%s\n" "        -h                       Display this help message."
        printf "%s\n" "        -d DIR -t DIR -v COMMIT  Setup compilation of OCaml."
        printf "\n"
        printf "%s\n" "Artifacts include:"
        printf "%s\n" "    flexlink (only on Windows)"
        printf "%s\n" "    ocaml"
        printf "%s\n" "    ocamlc.byte"
        printf "%s\n" "    ocamlc"
        printf "%s\n" "    ocamlc.opt"
        printf "%s\n" "    ocamlcmt"
        printf "%s\n" "    ocamlcp.byte"
        printf "%s\n" "    ocamlcp"
        printf "%s\n" "    ocamlcp.opt"
        printf "%s\n" "    ocamldebug"
        printf "%s\n" "    ocamldep.byte"
        printf "%s\n" "    ocamldep"
        printf "%s\n" "    ocamldep.opt"
        printf "%s\n" "    ocamldoc"
        printf "%s\n" "    ocamldoc.opt"
        printf "%s\n" "    ocamllex.byte"
        printf "%s\n" "    ocamllex"
        printf "%s\n" "    ocamllex.opt"
        printf "%s\n" "    ocamlmklib.byte"
        printf "%s\n" "    ocamlmklib"
        printf "%s\n" "    ocamlmklib.opt"
        printf "%s\n" "    ocamlmktop.byte"
        printf "%s\n" "    ocamlmktop"
        printf "%s\n" "    ocamlmktop.opt"
        printf "%s\n" "    ocamlobjinfo.byte"
        printf "%s\n" "    ocamlobjinfo"
        printf "%s\n" "    ocamlobjinfo.opt"
        printf "%s\n" "    ocamlopt.byte"
        printf "%s\n" "    ocamlopt"
        printf "%s\n" "    ocamlopt.opt"
        printf "%s\n" "    ocamloptp.byte"
        printf "%s\n" "    ocamloptp"
        printf "%s\n" "    ocamloptp.opt"
        printf "%s\n" "    ocamlprof.byte"
        printf "%s\n" "    ocamlprof"
        printf "%s\n" "    ocamlprof.opt"
        printf "%s\n" "    ocamlrun"
        printf "%s\n" "    ocamlrund"
        printf "%s\n" "    ocamlruni"
        printf "%s\n" "    ocamlyacc"
        printf "\n"
        printf "%s\n" "The compiler for the host machine ('ABI') comes from the PATH (like /usr/bin/gcc) as detected by OCaml's ./configure"
        printf "%s\n" "script, except on Windows machines where https://github.com/metastack/msvs-tools#msvs-detect is used to search"
        printf "%s\n" "for Visual Studio compiler installations."
        printf "\n"
        printf "%s\n" "The expectation we place on any user of this script who wants to cross-compile is that they understand what an ABI is,"
        printf "%s\n" "and how to obtain a SYSROOT for their target ABI. If you want an OCaml cross-compiler, you will need to use"
        printf "%s\n" "the '-a TARGETABIS' option."
        printf "\n"
        printf "%s\n" "To generate 32-bit machine code from OCaml, the host ABI for the OCaml native compiler must be 32-bit. And to generate"
        printf "%s\n" "64-bit machine code from OCaml, the host ABI for the OCaml native compiler must be 64-bit. In practice this means you"
        printf "%s\n" "may want to pick a 32-bit cross compiler for your _host_ ABI (for example a GCC compiler in 32-bit mode on a 64-bit"
        printf "%s\n" "Intel host) and then set your _target_ ABI to be a different cross compiler (for example a GCC in 32-bit mode on a 64-bit"
        printf "%s\n" "ARM host). **You can and should use** a 32-bit or 64-bit cross compiler for your host ABI as long as it generates executables"
        printf "%s\n" "that can be run on your host platform. Apple Silicon is a common architecture where you cannot run 32-bit executables, so your"
        printf "%s\n" "choices for where to run 32-bit ARM executables are QEMU (slow) or a ARM64 board (limited memory; Raspberry Pi 4, RockPro 64,"
        printf "%s\n" "NVidia Jetson) or a ARM64 Snapdragon Windows PC with WSL2 Linux (limited memory) or AWS Graviton2 (cloud). ARM64 servers for"
        printf "%s\n" "individual resale are also becoming available."
        printf "\n"
        printf "%s\n" "Options"
        printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file"
        printf "%s\n" "   -t DIR: Target directory for the reproducible directory tree"
        printf "%s\n" "   -v COMMIT: Git commit or tag for https://github.com/ocaml/ocaml. Strongly prefer a commit id for much stronger"
        printf "%s\n" "      reproducibility guarantees"
        printf "%s\n" "   -u COMMIT: Git commit or tag for https://github.com/ocaml/ocaml for the host ABI. Defaults to -v COMMIT"
        printf "%s\n" "   -a TARGETABIS: Optional. A named list of self-contained Posix shell script that can be sourced to set the"
        printf "%s\n" "      compiler environment variables for the target ABI. If not specified then the OCaml environment"
        printf "%s\n" "      will be purely for the host ABI. All path should use the native host platform's path"
        printf "%s\n" "      conventions like '/usr' on Unix and 'C:\VS2019' on Windows, although relative paths from DKML dir are accepted"
        printf "%s\n" "      The format of TARGETABIS is: <DKML_TARGET_ABI1>=/path/to/script1;<DKML_TARGET_ABI2>=/path/to/script2;..."
        printf "%s\n" "      where:"
        printf "%s\n" "        DKML_TARGET_ABI - The target ABI"
        printf "%s\n" "          Values include: windows_x86, windows_x86_64, android_arm64v8a, darwin_x86_64, etc."
        printf "%s\n" "          Others are/will be documented on https://diskuv.gitlab.io/diskuv-ocaml"
        printf "%s\n" "      The Posix shell script will have an unexported \$DKMLDIR environment variable containing the directory"
        printf "%s\n" "        of .dkmlroot, and an unexported \$DKML_TARGET_ABI containing the name specified in the TARGETABIS option"
        printf "%s\n" "      The Posix shell script should set some or all of the following compiler environment variables:"
        printf "%s\n" "        PATH - The PATH environment variable. You can use \$PATH to add to the existing PATH. On Windows"
        printf "%s\n" "          which uses MSYS2, the PATH should be colon separated with each PATH entry a UNIX path like /usr/a.out"
        printf "%s\n" "        AS - The assembly language compiler that targets machine code for the target ABI. On Windows this"
        printf "%s\n" "          must be a MASM compiler like ml/ml64.exe"
        printf "%s\n" "        ASPP - The assembly language compiler and preprocessor that targets machine code for the target ABI."
        printf "%s\n" "          On Windows this must be a MASM compiler like ml/ml64.exe"
        printf "%s\n" "        CC - The C cross compiler that targets machine code for the target ABI"
        printf "%s\n" "        INCLUDE - For the MSVC compiler, the semicolon-separated list of standard C and Windows header"
        printf "%s\n" "          directories that should be based on the target ABI sysroot"
        printf "%s\n" "        LIB - For the MSVC compiler, the semicolon-separated list of C and Windows library directories"
        printf "%s\n" "          that should be based on the target ABI sysroot"
        printf "%s\n" "        COMPILER_PATH - For the GNU compiler (GCC), the colon-separated list of system header directories"
        printf "%s\n" "          that should be based on the target ABI sysroot"
        printf "%s\n" "        CPATH - For the CLang compiler (including Apple CLang), the colon-separated list of system header"
        printf "%s\n" "          directories that should be based on the target ABI sysroot"
        printf "%s\n" "        LIBRARY_PATH - For the GNU compiler (GCC) and CLang compiler (including Apple CLang), the"
        printf "%s\n" "          colon-separated list of system library directory that should be based on the target ABI sysroot"
        printf "%s\n" "        PARTIALLD - The linker and flags to use for packaging (ocamlopt -pack) and for partial links"
        printf "%s\n" "          (ocamlopt -output-obj); only used while compiling the OCaml environment. This value"
        printf "%s\n" "          forms the basis of the 'native_pack_linker' of https://ocaml.org/api/compilerlibref/Config.html"
        printf "%s\n" "   -b PREF: Required and used only for the MSVC compiler. This is the msvs-tools MSVS_PREFERENCE setting"
        printf "%s\n" "      needed to detect the Windows compiler for the host ABI. Not used when '-e DKMLHOSTABI' is specified."
        printf "%s\n" "      Defaults to '$OPT_MSVS_PREFERENCE' which, because it does not include '@',"
        printf "%s\n" "      will not choose a compiler based on environment variables that would disrupt reproducibility."
        printf "%s\n" "      Confer with https://github.com/metastack/msvs-tools#msvs-detect"
        printf "%s\n" "   -e DKMLHOSTABI: Optional. Use the Diskuv OCaml compiler detector find a host ABI compiler."
        printf "%s\n" "      Especially useful to find a 32-bit Windows host compiler that can use 64-bits of memory for the compiler."
        printf "%s\n" "      Values include: windows_x86, windows_x86_64, android_arm64v8a, darwin_x86_64, etc."
        printf "%s\n" "      Others are/will be documented on https://diskuv.gitlab.io/diskuv-ocaml. Defaults to an"
        printf "%s\n" "      the environment variable DKML_HOST_ABI, or if not defined then an autodetection of the host architecture."
        printf "%s\n" "   -i OCAMLCARGS: Optional. Extra arguments passed to ocamlc like -g to save debugging"
        printf "%s\n" "   -j OCAMLOPTARGS: Optional. Extra arguments passed to ocamlopt like -g to save debugging"
        printf "%s\n" "   -k HOSTABISCRIPT: Optional. A self-contained Posix shell script that can be sourced to set the"
        printf "%s\n" "      compiler environment variables for the host ABI. See '-a TARGETABIS' for the shell script semantics."
        printf "%s\n" "   -m HOSTCONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure for the host ABI. --with-flexdll"
        printf "%s\n" "      and --host will have already been set appropriately, but you can override the --host heuristic by adding it"
        printf "%s\n" "      to -m HOSTCONFIGUREARGS"
        printf "%s\n" "   -n TARGETCONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure for the target ABI. --with-flexdll"
        printf "%s\n" "      and --host will have already been set appropriately, but you can override the --host heuristic by adding it"
        printf "%s\n" "      to -n TARGETCONFIGUREARGS"
        printf "%s\n" "   -r Only build ocamlrun, Stdlib and the other libraries. Cannot be used with -a TARGETABIS"
    } >&2
}

SETUP_ARGS=()
BUILD_HOST_ARGS=()
BUILD_CROSS_ARGS=()

DKMLDIR=
DKMLHOSTABI=${DKML_HOST_ABI:-}
HOST_GIT_COMMITID_OR_TAG=
TARGET_GIT_COMMITID_OR_TAG=
TARGETDIR=
TARGETABIS=
MSVS_PREFERENCE="$OPT_MSVS_PREFERENCE"
RUNTIMEONLY=OFF
while getopts ":d:v:u:t:a:b:e:i:j:k:m:n:rh" opt; do
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
            # Make into absolute path
            DKMLDIR_1=$(dirname "$DKMLDIR")
            DKMLDIR_1=$(cd "$DKMLDIR_1" && pwd)
            DKMLDIR_2=$(basename "$DKMLDIR")
            DKMLDIR="$DKMLDIR_1/$DKMLDIR_2"
        ;;
        v )
            TARGET_GIT_COMMITID_OR_TAG="$OPTARG"
            SETUP_ARGS+=( -v "$TARGET_GIT_COMMITID_OR_TAG" )
        ;;
        u )
            HOST_GIT_COMMITID_OR_TAG="$OPTARG"
            SETUP_ARGS+=( -v "$HOST_GIT_COMMITID_OR_TAG" )
        ;;        
        t )
            TARGETDIR="$OPTARG"
            SETUP_ARGS+=( -t . )
            BUILD_HOST_ARGS+=( -t . )
            BUILD_CROSS_ARGS+=( -t . )
        ;;
        a )
            TARGETABIS="$OPTARG"
        ;;
        b )
            MSVS_PREFERENCE="$OPTARG"
            SETUP_ARGS+=( -b "$OPTARG" )
        ;;
        e )
            DKMLHOSTABI="$OPTARG"
        ;;
        i )
            SETUP_ARGS+=( -i "$OPTARG" )
            BUILD_HOST_ARGS+=( -i "$OPTARG" )
            BUILD_CROSS_ARGS+=( -i "$OPTARG" )
        ;;
        j )
            SETUP_ARGS+=( -j "$OPTARG" )
            BUILD_HOST_ARGS+=( -j "$OPTARG" )
            BUILD_CROSS_ARGS+=( -j "$OPTARG" )
        ;;
        k )
            SETUP_ARGS+=( -k "$OPTARG" )
            BUILD_HOST_ARGS+=( -k "$OPTARG" )
        ;;
        m )
            SETUP_ARGS+=( -m "$OPTARG" )
            BUILD_HOST_ARGS+=( -m "$OPTARG" )
        ;;
        n )
            SETUP_ARGS+=( -n "$OPTARG" )
            BUILD_CROSS_ARGS+=( -n "$OPTARG" )
        ;;
        r )
            SETUP_ARGS+=( -r )
            BUILD_HOST_ARGS+=( -r )
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

if [ -z "$DKMLDIR" ] || [ -z "$TARGET_GIT_COMMITID_OR_TAG" ] || [ -z "$TARGETDIR" ]; then
    printf "%s\n" "Missing required options" >&2
    usage
    exit 1
fi
if [ -z "$HOST_GIT_COMMITID_OR_TAG" ]; then
    HOST_GIT_COMMITID_OR_TAG=$TARGET_GIT_COMMITID_OR_TAG
fi
if [ "$RUNTIMEONLY" = ON ] && [ -n "$TARGETABIS" ]; then
    printf "-r and -a TARGETABIS cannot be used at the same time\n" >&2
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
TARGETDIR_UNIX=$(install -d "$TARGETDIR" && cd "$TARGETDIR" && pwd) # better than cygpath: handles TARGETDIR=. without trailing slash, and works on Unix/Windows
if [ -x /usr/bin/cygpath ]; then
    OCAMLSRC_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/src/ocaml")
    OCAMLSRC_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/src/ocaml")
    TARGETDIR_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX")
else
    OCAMLSRC_UNIX="$TARGETDIR_UNIX/src/ocaml"
    OCAMLSRC_MIXED="$OCAMLSRC_UNIX"
    TARGETDIR_MIXED="$TARGETDIR_UNIX"
fi

# To be portable whether we build scripts in a container or not, we
# change the directory to always be in the DKMLDIR (just like a container
# sets the directory to be /work)
cd "$DKMLDIR"

# Set DKMLSYS_CAT and other things
autodetect_system_binaries

# Set BUILDHOST_ARCH
autodetect_buildhost_arch

# Add options that have defaults
if [ -z "$DKMLHOSTABI" ]; then
    DKMLHOSTABI="$BUILDHOST_ARCH"
fi
SETUP_ARGS+=( -b "'$MSVS_PREFERENCE'" -e "$DKMLHOSTABI" )
BUILD_HOST_ARGS+=( -b "'$MSVS_PREFERENCE'" -e "$DKMLHOSTABI" )
BUILD_CROSS_ARGS+=( -e "$DKMLHOSTABI" )

# Find OCaml patch
# Source: https://github.com/EduardoRFS/reason-mobile/tree/master/patches/ocaml/files or https://github.com/anmonteiro/nix-overlays/tree/master/cross
find_ocaml_crosscompile_patch() {
    find_ocaml_crosscompile_patch_VER=$1
    shift
    case "$find_ocaml_crosscompile_patch_VER" in
    4.11.*)
        OCAMLPATCHFILE=reproducible-compile-ocaml-cross_4_11.patch
        OCAMLPATCHEXTRA= # TODO
        ;;
    4.12.*)
        OCAMLPATCHFILE=reproducible-compile-ocaml-cross_4_12.patch
        OCAMLPATCHEXTRA=reproducible-compile-ocaml-cross_4_12_extra.patch
        ;;
    4.13.*)
        # shellcheck disable=SC2034
        OCAMLPATCHFILE=reproducible-compile-ocaml-cross_4_13.patch
        # shellcheck disable=SC2034
        OCAMLPATCHEXTRA= # TODO
        ;;
    5.00.*)
        # shellcheck disable=SC2034
        OCAMLPATCHFILE=reproducible-compile-ocaml-cross_5_00.patch
        # shellcheck disable=SC2034
        OCAMLPATCHEXTRA=reproducible-compile-ocaml-cross_5_00_extra.patch
        ;;
    *)
        echo "FATAL: There is no cross-compiling patch file yet for OCaml $find_ocaml_crosscompile_patch_VER" >&2
        exit 107
        ;;
    esac
}

apply_ocaml_crosscompile_patch() {
    apply_ocaml_crosscompile_patch_PATCHFILE=$1
    shift
    apply_ocaml_crosscompile_patch_SRCDIR=$1
    shift

    apply_ocaml_crosscompile_patch_SRCDIR_MIXED="$apply_ocaml_crosscompile_patch_SRCDIR"
    apply_ocaml_crosscompile_patch_PATCH_MIXED="$PWD"/vendor/dkml-component-ocamlcompiler/src/$apply_ocaml_crosscompile_patch_PATCHFILE
    if [ -x /usr/bin/cygpath ]; then
        apply_ocaml_crosscompile_patch_SRCDIR_MIXED=$(/usr/bin/cygpath -aw "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED")
        apply_ocaml_crosscompile_patch_PATCH_MIXED=$(/usr/bin/cygpath -aw "$apply_ocaml_crosscompile_patch_PATCH_MIXED")
    fi
    # Before packaging any of these artifacts the CI will likely do a `git clean -d -f -x` to reduce the
    # size and increase the safety of the artifacts. So we do a `git commit` after we have patched so
    # the reproducible source code has the patches applied, even after the `git clean`.
    # log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" apply --verbose "$apply_ocaml_crosscompile_patch_PATCH_MIXED"
    log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" config user.email "nobody+autopatcher@diskuv.ocaml.org"
    log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" config user.name  "Auto Patcher"
    git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" am --abort 2>/dev/null || true # clean any previous interrupted mail patch
    {
        printf "From: nobody+autopatcher@diskuv.ocaml.org\n"
        printf "Subject: OCaml cross-compiling patch %s\n" "$apply_ocaml_crosscompile_patch_PATCHFILE"
        printf "Date: 1 Jan 2000 00:00:00 +0000\n"
        printf "\n"
        printf "Reproducible patch\n"
        printf "\n"
        printf "%s\n" "---"
        $DKMLSYS_CAT "$apply_ocaml_crosscompile_patch_PATCH_MIXED"
    } | log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" am --ignore-date --committer-date-is-author-date
}

# ---------------------
# Get OCaml source code

# Set BUILDHOST_ARCH
autodetect_buildhost_arch

clean_ocaml_install() {
    clean_ocaml_install_DIR=$1
    shift
    for clean_ocaml_install_SUBDIR in bin lib man; do
        log_trace rm -rf "${clean_ocaml_install_DIR:?}/$clean_ocaml_install_SUBDIR"
    done
}

get_ocaml_source() {
    get_ocaml_source_COMMIT=$1
    shift
    get_ocaml_source_SRCUNIX="$1"
    shift
    get_ocaml_source_SRCMIXED="$1"
    shift
    get_ocaml_source_TARGETPLATFORM="$1"
    shift

    if [ ! -e "$get_ocaml_source_SRCUNIX/Makefile" ] || [ ! -e "$get_ocaml_source_SRCUNIX/.git" ]; then
        install -d "$get_ocaml_source_SRCUNIX"
        log_trace rm -rf "$get_ocaml_source_SRCUNIX" # clean any partial downloads
        # do NOT --recurse-submodules because we don't want submodules (ex. flexdll/) that are in HEAD but
        # are not in $get_ocaml_source_COMMIT
        log_trace git clone https://github.com/ocaml/ocaml "$get_ocaml_source_SRCMIXED"
        log_trace git -C "$get_ocaml_source_SRCMIXED" -c advice.detachedHead=false checkout "$get_ocaml_source_COMMIT"
    else
        # allow tag to move (for development and for emergency fixes), if the user chose a tag rather than a commit
        if git -C "$get_ocaml_source_SRCMIXED" tag -l "$get_ocaml_source_COMMIT" | awk 'BEGIN{nonempty=0} NF>0{nonempty+=1} END{exit nonempty==0}'; then git -C "$get_ocaml_source_SRCMIXED" tag -d "$get_ocaml_source_COMMIT"; fi
        log_trace git -C "$get_ocaml_source_SRCMIXED" fetch --tags
        log_trace git -C "$get_ocaml_source_SRCMIXED" -c advice.detachedHead=false checkout "$get_ocaml_source_COMMIT"
    fi
    log_trace git -C "$get_ocaml_source_SRCMIXED" submodule update --init --recursive

    # Remove any chmods we did in the previous build
    log_trace "$DKMLSYS_CHMOD" -R u+w "$get_ocaml_source_SRCMIXED"

    # OCaml compilation is _not_ idempotent. Example:
    #     config.status: creating Makefile.build_config
    #     config.status: creating Makefile.config
    #     config.status: creating tools/eventlog_metadata
    #     config.status: creating runtime/caml/m.h
    #     config.status: runtime/caml/m.h is unchanged
    #     config.status: creating runtime/caml/s.h
    #     config.status: runtime/caml/s.h is unchanged
    #     config.status: executing libtool commands
    #
    #     + env --unset=LIB --unset=INCLUDE --unset=PATH --unset=Lib --unset=Include --unset=Path PATH=/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/IDE/Extensions/Microsoft/IntelliCode/CLI:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.26.28801/bin/HostX64/x64:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/IDE/VC/VCPackages:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/IDE/CommonExtensions/Microsoft/TestWindow:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/IDE/CommonExtensions/Microsoft/TeamFoundation/Team Explorer:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/MSBuild/Current/bin/Roslyn:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Team Tools/Performance Tools/x64:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Team Tools/Performance Tools:/c/Program Files (x86)/Microsoft Visual Studio/Shared/Common/VSPerfCollectionTools/vs2019/x64:/c/Program Files (x86)/Microsoft Visual Studio/Shared/Common/VSPerfCollectionTools/vs2019/:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/Tools/devinit:/c/Program Files (x86)/Windows Kits/10/bin/10.0.18362.0/x64:/c/Program Files (x86)/Windows Kits/10/bin/x64:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/MSBuild/Current/Bin:/c/Windows/Microsoft.NET/Framework64/v4.0.30319:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/IDE/:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/Tools/:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin:/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:/z/source/.../windows_x86_64/Debug/dksdk/ocaml/bin:/c/Users/beckf/AppData/Local/Programs/DiskuvOCaml/1/bin:/c/Program Files/Git/cmd:/usr/bin:/c/Windows/System32:/c/Windows:/c/Windows/System32/Wbem:/c/Windows/System32/WindowsPowerShell/v1.0:/c/Windows/System32/OpenSSH LIB=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\lib\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\um\x64;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\lib\x64;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\atlmfc\lib\x64;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\lib\x64;;C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\ucrt\x64;;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\UnitTest\lib;C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\um\x64;lib\um\x64;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\lib\x64;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\atlmfc\lib\x64;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\lib\x64;;C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\ucrt\x64;;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\UnitTest\lib;C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\um\x64;lib\um\x64; INCLUDE=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\include;C:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\ucrt;C:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\shared;C:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\um;C:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\winrt;C:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\cppwinrt;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\include;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\atlmfc\include;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\include;;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\ucrt;;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\UnitTest\include;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\um;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\shared;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\winrt;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\cppwinrt;Include\um;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\include;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\atlmfc\include;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\include;;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\ucrt;;;C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\VS\UnitTest\include;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\um;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\shared;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\winrt;C:\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0\cppwinrt;Include\um; make flexdll
    #     make -C runtime BOOTSTRAPPING_FLEXLINK=yes ocamlrun.exe
    #     make[1]: Entering directory '/z/source/.../windows_x86_64/Debug/dksdk/ocaml/src/ocaml/runtime'
    #     cl -c -nologo -O2 -Gy- -MD    -D_CRT_SECURE_NO_DEPRECATE -DCAML_NAME_SPACE -DUNICODE -D_UNICODE -DWINDOWS_UNICODE=1 -DBOOTSTRAPPING_FLEXLINK -I"Z:\source\...\windows_x86_64\Debug\dksdk\ocaml\bin" -DCAMLDLLIMPORT= -DOCAML_STDLIB_DIR='L"Z:/source/.../windows_x86_64/Debug/dksdk/ocaml/lib/ocaml"'  -Fodynlink.b.obj dynlink.c
    #     dynlink.c
    #     link -lib -nologo -machine:AMD64  /out:libcamlrun.lib  interp.b.obj misc.b.obj stacks.b.obj fix_code.b.obj startup_aux.b.obj startup_byt.b.obj freelist.b.obj major_gc.b.obj minor_gc.b.obj memory.b.obj alloc.b.obj roots_byt.b.obj globroots.b.obj fail_byt.b.obj signals.b.obj signals_byt.b.obj printexc.b.obj backtrace_byt.b.obj backtrace.b.obj compare.b.obj ints.b.obj eventlog.b.obj floats.b.obj str.b.obj array.b.obj io.b.obj extern.b.obj intern.b.obj hash.b.obj sys.b.obj meta.b.obj parsing.b.obj gc_ctrl.b.obj md5.b.obj obj.b.obj lexing.b.obj callback.b.obj debugger.b.obj weak.b.obj compact.b.obj finalise.b.obj custom.b.obj dynlink.b.obj afl.b.obj win32.b.obj bigarray.b.obj main.b.obj memprof.b.obj domain.b.obj skiplist.b.obj codefrag.b.obj
    #     cl -nologo -O2 -Gy- -MD    -Feocamlrun.exe prims.obj libcamlrun.lib advapi32.lib ws2_32.lib version.lib  /link /subsystem:console /ENTRY:wmainCRTStartup && (test ! -f ocamlrun.exe.manifest || mt -nologo -outputresource:ocamlrun.exe -manifest ocamlrun.exe.manifest && rm -f ocamlrun.exe.manifest)
    #     libcamlrun.lib(win32.b.obj) : error LNK2019: unresolved external symbol flexdll_wdlopen referenced in function caml_dlopen
    #     libcamlrun.lib(win32.b.obj) : error LNK2019: unresolved external symbol flexdll_dlsym referenced in function caml_dlsym
    #     libcamlrun.lib(win32.b.obj) : error LNK2019: unresolved external symbol flexdll_dlclose referenced in function caml_dlclose
    #     libcamlrun.lib(win32.b.obj) : error LNK2019: unresolved external symbol flexdll_dlerror referenced in function caml_dlerror
    #     libcamlrun.lib(win32.b.obj) : error LNK2019: unresolved external symbol flexdll_dump_exports referenced in function caml_dlopen
    #     ocamlrun.exe : fatal error LNK1120: 5 unresolved externals
    # So clean directory every build
    log_trace git -C "$get_ocaml_source_SRCMIXED" clean -d -x -f
    log_trace git -C "$get_ocaml_source_SRCMIXED" submodule foreach --recursive "git clean -d -x -f -"

    # Install a synthetic msvs-detect
    if [ ! -e "$get_ocaml_source_SRCUNIX"/msvs-detect ]; then
        case "$get_ocaml_source_TARGETPLATFORM" in
          windows_*)
            DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_ABI=$get_ocaml_source_TARGETPLATFORM autodetect_compiler --msvs-detect "$WORK"/msvs-detect
            install "$WORK"/msvs-detect "$get_ocaml_source_SRCUNIX"/msvs-detect
            ;;
        esac
    fi

    # Windows needs flexdll, although 4.13.x+ has a "--with-flexdll" option which relies on the `flexdll` git submodule
    if [ ! -e "$get_ocaml_source_SRCUNIX"/flexdll ]; then
        log_trace downloadfile https://github.com/alainfrisch/flexdll/archive/0.39.tar.gz "$get_ocaml_source_SRCUNIX/flexdll.tar.gz" 51a6ef2e67ff475c33a76b3dc86401a0f286c9a3339ee8145053ea02d2fb5974
    fi
}

# Why multiple source directories?
# It is hard to reason about mutated source directories with different-platform object files, so we use a pristine source dir
# for the host and other pristine source dirs for each target.

clean_ocaml_install "$TARGETDIR_UNIX"
get_ocaml_source "$HOST_GIT_COMMITID_OR_TAG" "$OCAMLSRC_UNIX" "$OCAMLSRC_MIXED" "$BUILDHOST_ARCH"

# Find but do not apply the cross-compiling patches to the host ABI
_OCAMLVER=$(awk 'NR==1{print}' "$OCAMLSRC_UNIX"/VERSION)
find_ocaml_crosscompile_patch "$_OCAMLVER"

if [ -n "$TARGETABIS" ]; then
    if [ -z "$OCAMLPATCHEXTRA" ]; then
        printf "WARNING: OCaml version %s does not yet have patches for cross-compiling\n" "$_OCAMLVER" >&2
    fi

    # Loop over each target abi script file; each file separated by semicolons, and each term with an equals
    printf "%s\n" "$TARGETABIS" | sed 's/;/\n/g' | sed 's/^\s*//; s/\s*$//' > "$WORK"/tabi
    while IFS= read -r _abientry
    do
        _targetabi=$(printf "%s" "$_abientry" | sed 's/=.*//')
        # clean install
        clean_ocaml_install "$TARGETDIR_UNIX/opt/mlcross/$_targetabi"
        # git clone
        get_ocaml_source "$TARGET_GIT_COMMITID_OR_TAG" "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml" "$TARGETDIR_MIXED/opt/mlcross/$_targetabi/src/ocaml" "$_targetabi"
        # git patch src/ocaml
        apply_ocaml_crosscompile_patch "$OCAMLPATCHFILE"  "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml"
        if [ -n "$OCAMLPATCHEXTRA" ]; then
            apply_ocaml_crosscompile_patch "$OCAMLPATCHEXTRA" "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml"
        fi
        # git patch src/ocaml/flexdll
        apply_ocaml_crosscompile_patch "reproducible-compile-ocaml-cross_flexdll_0_39.patch" "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml/flexdll"
    done < "$WORK"/tabi
fi

# ---------------------------
# Finish

# Copy self into share/dkml-bootstrap/100-compile-ocaml
export BOOTSTRAPNAME=100-compile-ocaml
export DEPLOYDIR_UNIX="$TARGETDIR_UNIX"
DESTDIR=$TARGETDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
THISDIR=$(pwd)
if [ "$DESTDIR" = "$THISDIR" ]; then
    printf "Already deployed the reproducible scripts. Replacing them as needed\n"
    DKMLDIR=.
fi
# shellcheck disable=SC2016
COMMON_ARGS=(-d "$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME")
install_reproducible_common
install_reproducible_readme           vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-README.md
install_reproducible_file             vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-check_linker.sh
install_reproducible_file             vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-functions.sh
install_reproducible_file             vendor/dkml-component-ocamlcompiler/src/standard-compiler-env-to-ocaml-configure-env.sh
if [ -n "$TARGETABIS" ]; then
    _accumulator=
    # Loop over each target abi script file; each file separated by semicolons, and each term with an equals
    printf "%s\n" "$TARGETABIS" | sed 's/;/\n/g' | sed 's/^\s*//; s/\s*$//' > "$WORK"/tabi
    while IFS= read -r _abientry
    do
        _targetabi=$(printf "%s" "$_abientry" | sed 's/=.*//')
        _abiscript=$(printf "%s" "$_abientry" | sed 's/^[^=]*=//')

        # Since we want the ABI scripts to be reproducible, we install them in a reproducible place and set
        # the reproducible arguments (-a) to point to that reproducible place.
        _script="vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-targetabi-$_targetabi.sh"
        if [ -n "$_accumulator" ]; then
            _accumulator="$_accumulator;$_targetabi=$_script"
        else
            _accumulator="$_targetabi=$_script"
        fi
        install_reproducible_generated_file "$_abiscript" vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-targetabi-"$_targetabi".sh
    done < "$WORK"/tabi
    SETUP_ARGS+=( -a "$_accumulator" )
    BUILD_CROSS_ARGS+=( -a "$_accumulator" )
fi
install_reproducible_system_packages  vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-0-system.sh
install_reproducible_script_with_args vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-1-setup.sh "${COMMON_ARGS[@]}" "${SETUP_ARGS[@]}"
install_reproducible_script_with_args vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-2-build_host.sh "${COMMON_ARGS[@]}" "${BUILD_HOST_ARGS[@]}"
install_reproducible_script_with_args vendor/dkml-component-ocamlcompiler/src/reproducible-compile-ocaml-3-build_cross.sh "${COMMON_ARGS[@]}" "${BUILD_CROSS_ARGS[@]}"
