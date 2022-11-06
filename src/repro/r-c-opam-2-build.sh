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
# r-c-opam-2-build.sh -d DKMLDIR -t TARGETDIR
#
# Sets up the source code for a reproducible build

set -euf

# ------------------
# BEGIN Command line processing

OPT_MSVS_PREFERENCE='VS16.*;VS15.*;VS14.0' # KEEP IN SYNC with 1-setup.sh

usage() {
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    r-c-opam-2-build.sh" >&2
    printf "%s\n" "        -h                              Display this help message." >&2
    printf "%s\n" "        -d DIR -t DIR -a DKMLABI   Do compilation of Opam." >&2
    printf "%s\n" "Options" >&2
    printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    printf "%s\n" "   -t DIR: Target directory" >&2
    printf "%s\n" "   -n NUM: Number of CPUs. Autodetected with max of 8." >&2
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
TARGETDIR=
OCAMLHOME=
OCAMLBINDIR=
NUMCPUS=
PRESERVEGIT=OFF
DKMLABI=
while getopts ":d:t:n:a:b:c:e:f:h" opt; do
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
        t ) TARGETDIR="$OPTARG";;
        n ) NUMCPUS="$OPTARG";;
        a ) DKMLABI="$OPTARG";;
        b ) OPT_MSVS_PREFERENCE="$OPTARG";;
        c ) OCAMLHOME="$OPTARG";;
        f ) OCAMLBINDIR="$OPTARG";;
        e ) PRESERVEGIT="$OPTARG";;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$DKMLDIR" ] || [ -z "$TARGETDIR" ] || [ -z "$DKMLABI" ]; then
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
OPAMSRC_UNIX=$TARGETDIR_UNIX/src/opam
if [ -x /usr/bin/cygpath ]; then
    TARGETDIR_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX")
    OPAMSRC_MIXED=$(/usr/bin/cygpath -am "$OPAMSRC_UNIX")
else
    TARGETDIR_MIXED="$TARGETDIR_UNIX"
    OPAMSRC_MIXED="$OPAMSRC_UNIX"
fi

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

# Start PATH from scratch. This is supposed to be reproducible. Also
# we don't want a prior DiskuvOCamlHome installation to be used (ex.
# if `flexlink` is in the PATH then `make compiler / ./shell/bootstrap-ocaml.sh` will fail
# because it won't include the boostrap/ocaml-x.y.z/flexdll/ headers).
if [ -x /usr/bin/cygpath ]; then
    # include /c/Windows/System32 at end which is necessary for (at minimum) OCaml's shell/msvs-detect
    PATH=/usr/bin:/bin:$(/usr/bin/cygpath -S)
else
    PATH=/usr/bin:/bin
fi
if [ -n "$OCAMLHOME" ]; then
    validate_and_explore_ocamlhome "$OCAMLHOME"
    # add ocaml, ocamlc, etc.
    POST_BOOTSTRAP_PATH="$DKML_OCAMLHOME_UNIX"/"$DKML_OCAMLHOME_BINDIR_UNIX":"$PATH"
    USE_BOOTSTRAP=OFF
elif [ -n "$OCAMLBINDIR" ]; then
    if [ ! -x "$OCAMLBINDIR/ocaml" ] && [ ! -x "$OCAMLBINDIR/ocaml.exe" ]; then
        printf "FATAL: No ocaml found in -f %s\n" "$OCAMLBINDIR" >&2
        exit 1
    fi
    if [ ! -x "$OCAMLBINDIR/ocamlc" ] && [ ! -x "$OCAMLBINDIR/ocamlc.exe" ]; then
        printf "FATAL: No ocamlc found in -f %s\n" "$OCAMLBINDIR" >&2
        exit 1
    fi
    if [ -x /usr/bin/cygpath ]; then
        OCAMLBINDIR_UNIX=$(/usr/bin/cygpath -a "$OCAMLBINDIR")
    else
        OCAMLBINDIR_UNIX=$OCAMLBINDIR
    fi
    # add ocaml, ocamlc, etc.
    POST_BOOTSTRAP_PATH="$OCAMLBINDIR_UNIX":"$PATH"
    USE_BOOTSTRAP=OFF
else
    # add the bootstrap that Opam builds with `lib-pkg`. The packages are all
    # installed directly into the bootstrap (similar to an Opam switch).
    POST_BOOTSTRAP_PATH="$OPAMSRC_UNIX"/bootstrap/ocaml/bin:"$PATH"
    USE_BOOTSTRAP=ON
fi

# Set NUMCPUS if unset from autodetection of CPUs
autodetect_cpus

# Set DKML_POSIX_SHELL
autodetect_posix_shell

# Autodetect compiler like Visual Studio on Windows.
DKML_TARGET_ABI="$DKMLABI" autodetect_compiler "$WORK"/launch-compiler.sh
if [ -n "$OCAML_HOST_TRIPLET" ]; then
    BOOTSTRAP_EXTRA_OPTS="--host=$OCAML_HOST_TRIPLET"
else
    BOOTSTRAP_EXTRA_OPTS=""
fi

if is_unixy_windows_build_machine; then
    printf "%s" "cl.exe, if detected: "
    "$WORK"/launch-compiler.sh which cl.exe
    "$WORK"/launch-compiler.sh printf "%s\n" "INCLUDE: ${INCLUDE:-}"
    "$WORK"/launch-compiler.sh printf "%s\n" "LIBS: ${LIBS:-}"
fi

# Just like OCaml's ./configure, Opam uses non-standard constructions like
# `$CC ... $LDFLAGS`! That will cause unrecognized options many many times.
{
    printf "#!%s\n" "$DKML_POSIX_SHELL"
    printf "if [ -n \"\${LD:-}\" ]; then\n"
    # exec env LD="$LD ${LDFLAGS:-}" LDFLAGS= $@
    printf "  exec env LD=\"\$LD \${LDFLAGS:-}\" LDFLAGS= \"\$@\"\n"
    printf "else\n"
    # exec env $@
    printf "  exec env \"\$@\"\n"
    printf "fi\n"
} > "$WORK"/fixup-opam-compiler-env.sh
chmod +x "$WORK"/fixup-opam-compiler-env.sh

# Running through the `make compiler`, `make lib-pkg` + `configure` process should be done
# as one atomic unit. A failure in an intermediate step can cause subsequent `make compiler`
# or `make lib-pkg` or `configure` to fail. So we completely clean (`distclean`) until
# we have successfully completed a single run all the way to `configure`.
if [ ! -e "$OPAMSRC_UNIX/src/ocaml-flags-configure.sexp" ]; then
    # Clear out all intermediate build files
    log_trace vendor/drd/src/unix/private/r-c-opam-9-trim.sh -d . -t "$TARGETDIR_UNIX" -e "$PRESERVEGIT"

    # If no OCaml home, let Opam create its own Ocaml compiler which Opam will use to compile
    # all of its required Ocaml dependencies
    if [ "$USE_BOOTSTRAP" = ON ]; then
        # No OCaml home. Do Opam bootstrap
        # --------------------------------

        # Make sure at least flexdll is available for the upcoming 'make compiler'
        #   We'll need md5sum. On macOS this may be in homebrew (/usr/local/bin).
        OLDPATH=$PATH
        PATH=/usr/local/bin:$PATH
        log_trace make -C "$OPAMSRC_UNIX"/src_ext cache-archives
        PATH=$OLDPATH

        # We do what the following does (with customization): `make -C "$OPAMSRC_UNIX" compiler -j "$NUMCPUS"`
        pushd "$OPAMSRC_UNIX"
        if ! log_trace --return-error-code "$WORK"/launch-compiler.sh "$WORK"/fixup-opam-compiler-env.sh \
            BOOTSTRAP_EXTRA_OPTS="$BOOTSTRAP_EXTRA_OPTS" BOOTSTRAP_OPT_TARGET=opt.opt BOOTSTRAP_ROOT=.. BOOTSTRAP_DIR=bootstrap \
            ./shell/bootstrap-ocaml.sh auto;
        then
            # dump the `configure` script and display it with a ==> marker and line numbers (config.log reports the offending line numbers)
            marker="=-=-=-=-=-=-=-= configure script that errored =-=-=-=-=-=-=-="
            find bootstrap -maxdepth 2 -name configure | while read -r b; do
                printf "%s\n" "$marker" >&2
                awk '{print NR,$0}' "$b" >&2
            done
            # dump the config.log and display it with a ==> marker
            printf "\n" >&2
            find bootstrap -maxdepth 2 -name config.log -exec tail -n+0 {} \; >&2
            # tell how to get real error
            printf "%s\n" "FATAL: Failed ./shell/bootstrap-ocaml.sh. Original error should be above the numbered script that starts with: $marker"
            exit 1
        fi
        popd

        # Install Opam's dependencies as findlib packages to the bootstrap compiler
        # Note: We could add `OPAM_0INSTALL_SOLVER_ENABLED=true` but unclear if that is a good idea.
        log_trace "$WORK"/launch-compiler.sh make -C "$OPAMSRC_UNIX" lib-pkg -j "$NUMCPUS"
    fi

    # Standard autotools ./configure
    # - MSVS_PREFERENCE is used by OCaml's shell/msvs-detect, and is not used for non-Windows systems.
    # Note: The launch-compiler.sh are needed on jonahbeckford desktops for 32-bit Windows builds, but not on GitLab CI for 32-bit Windows.
    pushd "$OPAMSRC_UNIX"
    if [ "$USE_BOOTSTRAP" = OFF ]; then
        # `--with-vendored-deps` is what used to be `make lib-ext`, which extracted the source for Opam dependencies
        # and expected `make` to build a local Dune executable and do a recursive vendored Dune build. In contrast `make lib-pkg`
        # does a bootstrap which is an OCaml installation (bin/ with OCaml binaries, similar to Opam switch).
        log_trace env PATH="$POST_BOOTSTRAP_PATH" MSVS_PREFERENCE="$OPT_MSVS_PREFERENCE" "$WORK"/launch-compiler.sh "$WORK"/fixup-opam-compiler-env.sh ./configure --prefix="$TARGETDIR_MIXED" --with-vendored-deps
    else
        log_trace env PATH="$POST_BOOTSTRAP_PATH" MSVS_PREFERENCE="$OPT_MSVS_PREFERENCE" "$WORK"/launch-compiler.sh "$WORK"/fixup-opam-compiler-env.sh ./configure --prefix="$TARGETDIR_MIXED"
    fi
    popd
fi

if [ "$USE_BOOTSTRAP" = ON ]; then
    # Diagnostics for OCaml libraries
    log_trace env PATH="$POST_BOOTSTRAP_PATH" ocamlfind list
    log_trace env PATH="$POST_BOOTSTRAP_PATH" ocamlfind printconf

    # Should not be needed: QUERIED_OCAMLFIND_CONF=$(env PATH="$POST_BOOTSTRAP_PATH" ocamlfind printconf conf)
fi

# Don't let any parent Opam / Dune / OCaml context interfere with the building of Opam
safe_run() {
    # OCAMLFIND_CONF="$QUERIED_OCAMLFIND_CONF"
    log_trace env \
        -u DUNE_SOURCEROOT \
        -u DUNE_OCAML_HARDCODED \
        -u OCAML_TOPLEVEL_PATH \
        -u CAML_LD_LIBRARY_PATH \
        -u OPAM_SWITCH_PREFIX \
        -u OCAMLFIND_CONF \
        PATH="$POST_BOOTSTRAP_PATH" \
        "$@"
}

# At this point we have compiled _all_ of Opam dependencies if we used `lib-pkg` ...
# if we used `lib-ext` the following `make` will build Dune and other Opam dependencies.
# In both cases `make` will end up building Opam itself.
safe_run make -C "$OPAMSRC_UNIX" # parallel is unreliable, especially on Windows
safe_run make -C "$OPAMSRC_UNIX" install

# At this point both `lib-pkg` and `lib-ext` should have provided a Dune executable.
safe_dune() {
    if [ -e "$OPAMSRC_UNIX"/src_ext/dune-local/dune.exe ]; then
        # use Dune directly if it is built locally by Opam through `lib-ext` and `make`
        safe_run "$OPAMSRC_UNIX"/src_ext/dune-local/dune.exe "$@"
    else
        # otherwise get dune from the PATH (which includes `lib-pkg` installed bootstrap binaries)
        safe_run dune "$@"
    fi
}

# The `make` scripts run the Dune `xxx.install` targets, which will only build the "default" context.
# We want all contexts, especially if a build tool has placed a custom `dune-workspace` in the Opam
# source directory that includes cross-compiling contexts.
#
# Nit: opam-putenv.exe is not included below ... because for now Windows does not have a cross-compiling
# DKML context.
#
# End-goal: _build/install/default.CONTEXT/bin/opam and other executables (perhaps libraries as well) populated
#
# The dune from the "dune-local" of Opam that is invoked via Opam's Makefile and hardcodes environment
# variables (confer Makefile.config in Opam). These hardcoded environment variables (INCLUDE, LIB, CPATH,
# LIBRARY_PATH) force a single compiler that can't do any cross-compiling!
#
# So we will use `dune` accessible in the post boostrap PATH, and use whatever is present currently
# for the compiler environment variables.
# That does mean that MSVC compiler won't work (you need vcvarsbat.cmd or INCLUDE/LIB/CPATH), but almost all
# other compilers can work directly from the PATH (ex. clang/gcc) and do cross-compilation using
# the flags available in `ocamlc -config` (ex. clang -arch xxx on macOS, gcc -m32 on Linux).

safe_dune printenv --root "$OPAMSRC_MIXED" --verbose

ccomp_type=$(safe_run ocamlc -config | tr -d '\r' | grep ccomp_type | awk '{print $2}')
echo "ccomp_type is $ccomp_type"
if [ "$ccomp_type" != msvc ]; then
    # We are not using MSVC! We can do cross-compilation directly with Dune.
    #
    # Advanced: There is no way to actually support MSVC cross-compilation with Dune unless the dune-workspace
    # sets INCLUDE and LIB separately for each context (ex. INCLUDE/LIB for Windows ARM64, which is different for Windows x86_64).
    # We don't have the detection logic here to see if the dune-workspace is correct.

    # --------
    # METHOD 1
    # --------
    #   1. For all cross-compiling contexts
    # find "$OPAMSRC_UNIX/_build" -mindepth 1 -maxdepth 1 -name "default.*" | while read -r context_dir; do
    #     # ex. default.darwin_arm64
    #     context_basename=$(basename "$context_dir")
    #     # 2. Build the executables we want
    #     safe_dune build --profile=release --root "$OPAMSRC_MIXED" \
    #         _build/install/"$context_basename"/bin/opam \
    #         _build/install/"$context_basename"/bin/opam-installer
    # done

    # --------
    # METHOD 2
    # --------
    #   1. Run the @install for the packages we care about
    #       This installs more than we need (ex. lib/opam/META, etc.)
    safe_dune build --profile=release --root "$OPAMSRC_MIXED" \
        --only-packages opam-state,opam-solver,opam-core,opam-format,opam-repository,opam-client,opam,opam-installer \
        @install
fi
