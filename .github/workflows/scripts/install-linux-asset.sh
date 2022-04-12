#!/bin/sh
set -eufx

# $1 = 4.13.1 (example)
ocaml_compiler=$1
shift

# Install opam
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

# Install staging ocamlrun
opam install ./dkml-component-staging-ocamlrun.opam --with-test  --yes
