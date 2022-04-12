#!/bin/sh
set -eufx

# until published in Opam repository
opam pin dkml-install                         'https://github.com/diskuv/dkml-install-api.git#main' --no-action --yes
opam pin dkml-install-runner                  'https://github.com/diskuv/dkml-install-api.git#main' --no-action --yes
opam pin dkml-package-console                 'https://github.com/diskuv/dkml-install-api.git#main' --no-action --yes
opam pin dkml-component-staging-curl          'https://github.com/diskuv/dkml-component-curl.git#main' --no-action --yes
opam pin dkml-component-staging-unixutils     'https://github.com/diskuv/dkml-component-unixutils.git#main' --no-action --yes
opam pin dkml-component-network-unixutils     'https://github.com/diskuv/dkml-component-unixutils.git#main' --no-action --yes
