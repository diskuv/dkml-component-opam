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
# r-c-opam-9-trim.sh -d DKMLDIR -t TARGETDIR
#
# Remove intermediate files from reproducible target directory

set -euf

# ------------------
# BEGIN Command line processing

usage() {
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    r-c-opam-9-trim.sh" >&2
    printf "%s\n" "        -h                     Display this help message." >&2
    printf "%s\n" "        -d DIR -t DIR          Do trimming of Opam install." >&2
    printf "%s\n" "Options" >&2
    printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    printf "%s\n" "   -t DIR: Target directory" >&2
    printf "%s\n" "   -e ON|OFF: Optional; default is OFF. If ON will preserve .git folders in the target directory" >&2
}

DKMLDIR=
TARGETDIR=
PRESERVEGIT=OFF
while getopts ":d:t:e:h" opt; do
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
        ;;
        t ) TARGETDIR="$OPTARG";;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
        e ) PRESERVEGIT="$OPTARG";;
    esac
done
shift $((OPTIND -1))

if [ -z "$DKMLDIR" ] || [ -z "$TARGETDIR" ]; then
    printf "%s\n" "Missing required options" >&2
    usage
    exit 1
fi

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
OPAMSRC="$TARGETDIR_UNIX/src/opam"

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

# Opam already includes a command to get rid of all build files
if [ -e "$OPAMSRC/Makefile" ]; then
    log_trace make -C "$OPAMSRC" distclean
fi

# Also get rid of Git files
if cmake_flag_off "$PRESERVEGIT" && [ -e "$OPAMSRC/.git" ]; then
    rm -rf "$OPAMSRC/.git"
fi
