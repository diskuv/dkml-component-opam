#!/bin/sh
set -eufx

TARBALL=$1
shift

# Make absolute path since `tar C`` will change directory
TARBALL=$(realpath "$TARBALL")

# Set Opam environment
PATH=/work/opambin:$PATH
export OPAMROOT=/work/opamroot

tar cvCfz "$(opam var dkml-component-staging-ocamlrun:share)" "$TARBALL" .
