#!/usr/bin/env bash
# This is a clone of https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/shell/check_linker,
# with some shellcheck linting fixes applied.
# Licensed under https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/LICENSE - LGPL 2.1 with special linking exceptions

# Ensure that the Microsoft Linker isn't being messed up by /usr/bin/link
FIRST=1
FAULT=0
PREPEND=
while IFS= read -r line; do
  OUTPUT=$("$line" --version 2>/dev/null | head -1 | grep -F "Microsoft (R) Incremental Linker")
  if [ "$OUTPUT" = "" ] && [ $FIRST -eq 1 ] ; then
    FAULT=1
  elif [ $FAULT -eq 1 ] ; then
    PREPEND=$(dirname "$line"):
    FAULT=0
  fi
done < <(which --all link)

echo "$PATH_PREPEND$PREPEND"
