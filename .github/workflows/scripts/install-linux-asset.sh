#!/bin/sh
set -eufx

COMPONENT=$1
shift

# $1 = 4.13.1 (example)
ocaml_compiler=$1
shift

# Install opam
install -d /work/opambin
{
    ## Where should it be installed ? [/usr/local/bin] /work/opambin
    printf "/work/opambin\n" 
} | sh -x .github/workflows/scripts/opam/install.sh

# Set Opam environment
PATH=/work/opambin:$PATH
export OPAMROOT=/work/opamroot

# Init Opam
#   No sandboxing since we are already in a Docker container
opam init --disable-sandboxing

# Create Switch
opam switch create ci "$ocaml_compiler"
eval "$(opam env --switch ci)"

# Diagnostic
opam var

# Do pins
sh -x .github/workflows/scripts/pin-unix-asset.sh

# Install component
OPAMROOT=$(opam var root)
if ! opam install ./"$COMPONENT".opam --with-test  --yes; then
    printf "\n\n========= [START OF TROUBLESHOOTING] ===========\n\n" >&2
    env >&2

    find "$OPAMROOT"/log -mindepth 1 -maxdepth 1 -name "*.env" ! -name "log-*.env" ! -name "ocaml-variants-*.env" | head -n1 | while read -r dump_on_error_LOG; do
        dump_on_error_BLOG=$(basename "$dump_on_error_LOG")
        printf "\n\n========= [TROUBLESHOOTING] %s ===========\n# To save space, this is only one of the many similar Opam environment files that have been printed.\n\n" "$dump_on_error_BLOG" >&2
        cat "$dump_on_error_LOG" >&2
    done

    find "$OPAMROOT"/log -mindepth 1 -maxdepth 1 -name "*.out" ! -name "log-*.out" ! -name "ocaml-variants-*.out" | while read -r dump_on_error_LOG; do
        dump_on_error_BLOG=$(basename "$dump_on_error_LOG")
        printf "\n\n========= [TROUBLESHOOTING] %s ===========\n\n" "$dump_on_error_BLOG" >&2
        cat "$dump_on_error_LOG" >&2
    done

    printf "Scroll up to see the [TROUBLESHOOTING] logs that begin at the [START OF TROUBLESHOOTING] line\n" >&2
    exit 109
fi
