#!/bin/sh
set -eufx

COMPONENT=$1
shift

TARBALL=$1
shift

# Make absolute path since `tar C`` will change directory
TARBALL=$(realpath "$TARBALL")

# Set Opam environment
PATH=/work/opambin:$PATH
export OPAMROOT=/work/opamroot

_share=$(opam var "$COMPONENT":share)
tar cvCfz "$_share" "$TARBALL" .
