#!/bin/bash

set -e

function dokku() {
    # Redirect stdin to /dev/null to prevent ssh from consuming input
    # when called inside a `while read` loop
    ssh -o "StrictHostKeyChecking=no" dokku@"${DOKKU_HOST}" dokku "$@" < /dev/null
}

function info() {
    echo -e "\033[1;34m$1\033[0m"
}

function success() {
    echo -e "\033[1;32m$1\033[0m"
}

# Scale processes (e.g. worker=1)
if [ -n "$INPUT_PROCESS_SCALING" ]; then
    info "Scaling processes"
    scale_args=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        scale_args="$scale_args $line"
    done <<< "$INPUT_PROCESS_SCALING"
    if [ -n "$scale_args" ]; then
        # shellcheck disable=SC2086 # intentional word splitting
        dokku ps:scale "$DOKKU_APP" $scale_args
    fi
fi

success "Post-deploy configuration complete"
