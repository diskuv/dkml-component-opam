#!/bin/sh
set -x
export PATH="/cygdrive/d/cygwin/bin:$PATH"

# shellcheck disable=SC2155
export TMP="$(cygpath -a "$RUNNER_TEMP")"

if ! opam install ./"$COMPONENT".opam --with-test --yes; then
    OPAMROOT=$(opam var root)
    printf "\n\n========= [START OF TROUBLESHOOTING] ===========\n\n" >&2

    find "$OPAMROOT" -name config.log >&2
    find "$OPAMROOT" -name config.log | while read -r i; do
        dump_on_error_BLOG="$i"
        if [ -e "$dump_on_error_BLOG" ]; then
            printf "\n\n========= [TROUBLESHOOTING] %s ===========\n\n" "$dump_on_error_BLOG" >&2
            cat "$dump_on_error_BLOG" >&2
        fi
    done

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
