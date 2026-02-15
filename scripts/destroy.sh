#!/bin/bash

set -e

function dokku() {
    ssh -o "StrictHostKeyChecking=no" dokku@"${DOKKU_HOST}" dokku "$@"
}

if dokku apps:exists "$DOKKU_APP"; then
    dokku apps:destroy "$DOKKU_APP" --force
fi
