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
# @jonahbeckford: 2021-09-07
# - This file is licensed differently than the rest of the Diskuv OCaml distribution.
#   Keep the Apache License in this file since this file is part of the reproducible
#   build files.
#
######################################
# r-c-opam-1-setup.sh -d DKMLDIR -t TARGETDIR -g GIT_COMMITID_TAG_OR_DIR [-a DKMLABI]
#
# Sets up the source code for a reproducible build of Opam

set -euf

# ------------------
# BEGIN Command line processing

SETUP_ARGS=()
BUILD_ARGS=()
TRIM_ARGS=()

# Since installtime/windows/Machine/Machine.psm1 has minimum VS14 we only select that version
# or greater. We'll ignore '10.0' (Windows SDK 10) which may bundle Visual Studio 2015, 2017 or 2019.
# Also we do _not_ use the environment (ie. no '@' in MSVS_PREFERENCE) since that isn't reproducible,
# and also because it sets MSVS_* variables to empty if it thinks the environment is correct (but we
# _always_ want MSVS_* set since ./configure script branches on MSVS_* being non-empty).
OPT_MSVS_PREFERENCE='VS16.*;VS15.*;VS14.0' # KEEP IN SYNC with 2-build.sh

usage() {
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    r-c-opam-1-setup.sh" >&2
    printf "%s\n" "        -h                                  Display this help message." >&2
    printf "%s\n" "        -d DIR -t DIR -v COMMIT -a DKMLABI  Setup compilation of Opam." >&2
    printf "%s\n" "Options" >&2
    printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    printf "%s\n" "   -t DIR: Target directory" >&2
    printf "%s\n" "   -p PACKAGE_VERSION: If specified, override the package version" >&2
    printf "%s\n" "   -v COMMIT_OR_DIR: Git commit or tag or directory for the OCaml source code. Strongly prefer a" >&2
    printf "%s\n" "      commit id for much stronger reproducibility guarantees" >&2
    printf "%s\n" "   -u URL: Git repository url. Defaults to https://github.com/ocaml/opam. Unused if -v COMMIT is a" >&2
    printf "%s\n" "      directory" >&2
    printf "%s\n" "   -a DKMLABI: Target ABI for bootstrapping an OCaml compiler." >&2
    printf "%s\n" "      Ex. windows_x86, windows_x86_64" >&2
    printf "%s\n" "   -b PREF: The msvs-tools MSVS_PREFERENCE setting, needed only for Windows." >&2
    printf "%s\n" "      Defaults to '$OPT_MSVS_PREFERENCE' which, because it does not include '@'," >&2
    printf "%s\n" "      will not choose a compiler based on environment variables." >&2
    printf "%s\n" "      Confer with https://github.com/metastack/msvs-tools#msvs-detect" >&2
    printf "%s\n" "   -c OCAMLHOME: Optional. The home directory for OCaml containing usr/bin/ocamlc or bin/ocamlc," >&2
    printf "%s\n" "      and other OCaml binaries and libraries. If both -c and -f not specified then will this script" >&2
    printf "%s\n" "      will bootstrap its own OCaml home" >&2
    printf "%s\n" "   -f OCAMLBINDIR: Optional. The binary directory for OCaml ocamlc, and other OCaml binaries and" >&2
    printf "%s\n" "      and libraries. If both -c and -f not specified then will this script will bootstrap its own" >&2
    printf "%s\n" "      OCaml home" >&2
    printf "%s\n" "   -e ON|OFF: Optional; default is OFF. If ON will preserve .git folders in the target directory" >&2
}

DKMLDIR=
GIT_URL=https://github.com/ocaml/opam
GIT_COMMITID_TAG_OR_DIR=
TARGETDIR=
PRESERVEGIT=OFF
DKMLABI=
PACKAGE_VERSION=
while getopts ":d:u:v:t:a:b:c:e:f:p:h" opt; do
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
        u )
            GIT_URL="$OPTARG"
            SETUP_ARGS+=( -u "$GIT_URL" )
        ;;
        v )
            GIT_COMMITID_TAG_OR_DIR="$OPTARG"
            SETUP_ARGS+=( -v "$GIT_COMMITID_TAG_OR_DIR" )
        ;;
        t )
            TARGETDIR="$OPTARG"
            BUILD_ARGS+=( -t . )
            TRIM_ARGS+=( -t . )
            SETUP_ARGS+=( -t . )
        ;;
        a )
            DKMLABI="$OPTARG"
            BUILD_ARGS+=( -a "$OPTARG" )
            SETUP_ARGS+=( -a "$OPTARG" )
        ;;
        b )
            BUILD_ARGS+=( -b "$OPTARG" )
            SETUP_ARGS+=( -b "$OPTARG" )
        ;;
        c )
            BUILD_ARGS+=( -c "$OPTARG" )
            SETUP_ARGS+=( -c "$OPTARG" )
        ;;
        e )
            PRESERVEGIT="$OPTARG"
            SETUP_ARGS+=( -e "$PRESERVEGIT" )
        ;;
        f )
            BUILD_ARGS+=( -f "$OPTARG" )
            SETUP_ARGS+=( -f "$OPTARG" )
        ;;
        p )
            PACKAGE_VERSION="$OPTARG"
            SETUP_ARGS+=( -p "$OPTARG" )
        ;;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$DKMLDIR" ] || [ -z "$GIT_COMMITID_TAG_OR_DIR" ] || [ -z "$TARGETDIR" ] || [ -z "$DKMLABI" ]; then
    printf "%s\n" "Missing required options" >&2
    usage
    exit 1
fi

BUILD_ARGS+=( -e "$PRESERVEGIT" )
TRIM_ARGS+=( -e "$PRESERVEGIT" )

# END Command line processing
# ------------------

# shellcheck disable=SC2034
USERMODE=ON
# shellcheck disable=SC2034
STATEDIR=

# shellcheck disable=SC1091
. "$DKMLDIR/vendor/drc/unix/_common_tool.sh"

disambiguate_filesystem_paths

# Bootstrapping vars
TARGETDIR_UNIX=$(install -d "$TARGETDIR" && cd "$TARGETDIR" && pwd) # better than cygpath: handles TARGETDIR=. without trailing slash, and works on Unix/Windows
if [ -x /usr/bin/cygpath ]; then
    OPAMSRC_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/src/opam")
    OPAMSRC_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/src/opam")
else
    OPAMSRC_UNIX="$TARGETDIR_UNIX/src/opam"
    OPAMSRC_MIXED="$OPAMSRC_UNIX"
fi

# ensure git, if directory, is an absolute directory
if [ -d "$GIT_COMMITID_TAG_OR_DIR" ]; then
    if [ -x /usr/bin/cygpath ]; then
        GIT_COMMITID_TAG_OR_DIR=$(/usr/bin/cygpath -am "$GIT_COMMITID_TAG_OR_DIR")
    else
        # absolute directory
        buildhost_pathize "$GIT_COMMITID_TAG_OR_DIR"
        # shellcheck disable=SC2154
        GIT_COMMITID_TAG_OR_DIR="$buildhost_pathize_RETVAL"
    fi
fi

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

# Get the unpatched ocaml/opam source code ...

if [ -d "$GIT_COMMITID_TAG_OR_DIR" ]; then
    # If there is a directory of the source code, use that
    if [ ! -e "$OPAMSRC_UNIX/Makefile" ]; then
        log_trace install -d "$OPAMSRC_UNIX"
        log_trace rm -rf "$OPAMSRC_UNIX" # clean any partial downloads
        log_trace cp -rp "$GIT_COMMITID_TAG_OR_DIR" "$OPAMSRC_UNIX"
    fi

    # Make it git patchable if it is not a git repository already
    if [ ! -e "$OPAMSRC_UNIX/.git" ]; then
        log_trace git -C "$OPAMSRC_MIXED" init
        log_trace git -C "$OPAMSRC_MIXED" config user.email "nobody+autocommitter@diskuv.ocaml.org"
        log_trace git -C "$OPAMSRC_MIXED" config user.name  "Auto Committer"
        log_trace git -C "$OPAMSRC_MIXED" add -A
        log_trace git -C "$OPAMSRC_MIXED" commit -m "Commit from source tree"
        log_trace git -C "$OPAMSRC_MIXED" tag r-c-opam-1-setup-srctree
    fi

    # Move the repository to the expected tag
    log_trace git -C "$OPAMSRC_MIXED" stash
    log_trace git -C "$OPAMSRC_MIXED" -c advice.detachedHead=false checkout r-c-opam-1-setup-srctree
else
    if [ ! -e "$OPAMSRC_UNIX/Makefile" ] || [ ! -e "$OPAMSRC_UNIX/.git" ]; then
        log_trace rm -rf "$OPAMSRC_UNIX" # clean any partial downloads
        log_trace install -d "$OPAMSRC_UNIX"
        #   Instead of git clone we use git fetch --depth 1 so we do a shallow clone of the commit
        log_trace git -C "$OPAMSRC_MIXED" -c init.defaultBranch=master init
        log_trace git -C "$OPAMSRC_MIXED" remote add origin "$GIT_URL"
        log_trace git -C "$OPAMSRC_MIXED" fetch --depth 1 origin "$GIT_COMMITID_TAG_OR_DIR"
        log_trace git -C "$OPAMSRC_MIXED" reset --hard FETCH_HEAD
    else
        # Move the repository to the expected commit
        #   Git fetch can be very expensive after a shallow clone; we skip advancing the repository
        #   if the expected tag/commit is a commit and the actual git commit is the expected git commit
        git_head=$(log_trace git -C "$OPAMSRC_MIXED" rev-parse HEAD)
        if [ ! "$git_head" = "$GIT_COMMITID_TAG_OR_DIR" ]; then
            if git -C "$OPAMSRC_MIXED" tag -l "$GIT_COMMITID_TAG_OR_DIR" | awk 'BEGIN{nonempty=0} NF>0{nonempty+=1} END{exit nonempty==0}'; then git -C "$OPAMSRC_MIXED" tag -d "$GIT_COMMITID_TAG_OR_DIR"; fi # allow tag to move (for development and for emergency fixes)
            log_trace git -C "$OPAMSRC_MIXED" remote set-url origin "$GIT_URL"
            log_trace git -C "$OPAMSRC_MIXED" fetch origin --tags
            log_trace git -C "$OPAMSRC_MIXED" stash
            log_trace git -C "$OPAMSRC_MIXED" -c advice.detachedHead=false checkout "$GIT_COMMITID_TAG_OR_DIR"
        fi
    fi
fi

# REPLACE - msvs-detect
if [ ! -e "$OPAMSRC_UNIX"/shell/msvs-detect ] || [ ! -e "$OPAMSRC_UNIX"/shell/msvs-detect.complete ]; then
    DKML_TARGET_ABI=$DKMLABI autodetect_compiler --msvs-detect "$WORK"/msvs-detect
    install "$WORK"/msvs-detect "$OPAMSRC_UNIX"/shell/msvs-detect
    touch "$OPAMSRC_UNIX"/shell/msvs-detect.complete
fi

# Set the package version so that `opam --version` matches what is in dkml-component-*.opam:
if [ -n "${PACKAGE_VERSION:-}" ]; then
    # In `configure`:
    #   PACKAGE_VERSION='2.2.0~alpha~dev'
    #   PACKAGE_STRING='opam 2.2.0~alpha~dev'
    sed "s/PACKAGE_VERSION='[^']*'/PACKAGE_VERSION='""${PACKAGE_VERSION}""'/; s/PACKAGE_STRING='opam [^']*'/PACKAGE_STRING='opam ""${PACKAGE_VERSION}""'/" \
        "$OPAMSRC_UNIX"/configure > "$OPAMSRC_UNIX"/configure.new
    mv "$OPAMSRC_UNIX"/configure.new "$OPAMSRC_UNIX"/configure
    chmod +x "$OPAMSRC_UNIX"/configure

    # In `configure.ac` which is read directly by <opam>/src/core/dune:
    #   AC_INIT(opam,2.2.0~alpha~dev)
    sed "s/^AC_INIT(opam,.*)/AC_INIT(opam,${PACKAGE_VERSION})/" \
        "$OPAMSRC_UNIX"/configure.ac > "$OPAMSRC_UNIX"/configure.ac.new
    mv "$OPAMSRC_UNIX"/configure.ac.new "$OPAMSRC_UNIX"/configure.ac
fi

# Copy self into share/dkml-bootstrap/110co (short form of 110-compile-opam
# so Windows and macOS paths are short)
export BOOTSTRAPNAME=110co
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
install_reproducible_readme           vendor/component-opam/src/repro/r-c-opam-README.md
install_reproducible_system_packages  vendor/component-opam/src/repro/r-c-opam-0-system.sh
install_reproducible_script_with_args vendor/component-opam/src/repro/r-c-opam-1-setup.sh "${COMMON_ARGS[@]}" "${SETUP_ARGS[@]}"
install_reproducible_script_with_args vendor/component-opam/src/repro/r-c-opam-2-build.sh "${COMMON_ARGS[@]}" "${BUILD_ARGS[@]}"
install_reproducible_script_with_args vendor/component-opam/src/repro/r-c-opam-9-trim.sh  "${COMMON_ARGS[@]}" "${TRIM_ARGS[@]}"
