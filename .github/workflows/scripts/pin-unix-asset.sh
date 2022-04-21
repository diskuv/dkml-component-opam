#!/bin/sh
set -eufx

# until published in Opam repository
opamrun pin dkml-install                         'https://github.com/diskuv/dkml-install-api.git#main' --no-action --yes
opamrun pin dkml-install-runner                  'https://github.com/diskuv/dkml-install-api.git#main' --no-action --yes
opamrun pin dkml-package-console                 'https://github.com/diskuv/dkml-install-api.git#main' --no-action --yes
opamrun pin dkml-component-staging-curl          'https://github.com/diskuv/dkml-component-curl.git#main' --no-action --yes
opamrun pin dkml-component-staging-unixutils     'https://github.com/diskuv/dkml-component-unixutils.git#main' --no-action --yes
opamrun pin dkml-component-network-unixutils     'https://github.com/diskuv/dkml-component-unixutils.git#main' --no-action --yes

# GitHub stalls with:
#   <><> Error report <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
#   +- The following actions failed
#   | - fetch uucp 14.0.0
#   +-
# Example: https://github.com/diskuv/dkml-component-ocamlcompiler/runs/6060230260?check_suite_focus=true
# So pin it instead of download from Opam cache
opamrun pin uucp                                 'git+https://erratique.ch/repos/uucp.git#v14.0.0' --no-action --yes
