#!/bin/bash

set -e

function dokku() {
    ssh -o "StrictHostKeyChecking=no" dokku@"${DOKKU_HOST}" dokku "$@"
}

function info() {
    echo -e "\033[1;34m$1\033[0m"
}

function success() {
    echo -e "\033[1;32m$1\033[0m"
}

STORAGE_DIR="/var/lib/dokku/data/storage/${DOKKU_APP}"

info "Dokku app for preview deployment: $DOKKU_APP"

# Create the app if it doesn't exist
if ! dokku apps:exists "$DOKKU_APP"; then
    info "Creating Dokku app"
    dokku apps:create "$DOKKU_APP"
fi

info "Configuring app domain"
dokku domains:set "$DOKKU_APP" "$DOKKU_APP_DOMAIN"

info "Setting environment variables"
dokku config:set "$DOKKU_APP" \
    APP_ENV="preview" \
    APP_URL="http://${DOKKU_APP_DOMAIN}" --no-restart

# Extra env vars from input
if [ -n "$INPUT_ENV_VARS" ]; then
    info "Setting additional environment variables"
    env_args=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        env_args="$env_args $line"
    done <<< "$INPUT_ENV_VARS"
    if [ -n "$env_args" ]; then
        dokku config:set "$DOKKU_APP" $env_args --no-restart
    fi
fi

# Only set APP_KEY once to avoid it changing on every deploy
if ! dokku config:get "$DOKKU_APP" APP_KEY > /dev/null 2>&1; then
    info "Setting APP_KEY"
    dokku config:set "$DOKKU_APP" APP_KEY="base64:$(openssl rand -base64 32)" --no-restart
fi

info "Configuring reverse proxy headers"
dokku nginx:set "$DOKKU_APP" x-forwarded-for-value '$http_x_forwarded_for'
dokku nginx:set "$DOKKU_APP" x-forwarded-port-value '$http_x_forwarded_port'
dokku nginx:set "$DOKKU_APP" x-forwarded-proto-value '$http_x_forwarded_proto'

info "Setting up proxy ports"
dokku ports:set "$DOKKU_APP" "$INPUT_PORTS"

info "Ensuring storage directory exists"
dokku storage:ensure-directory "$DOKKU_APP" --chown root "$DOKKU_APP"

# Mount read/write storage volumes
if [ -n "$INPUT_STORAGE_MOUNTS" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Replace {STORAGE_DIR} token with actual path
        mount="${line//\{STORAGE_DIR\}/$STORAGE_DIR}"
        container_path="${mount#*:}"

        if ! dokku storage:list "$DOKKU_APP" | grep -q "$container_path"; then
            info "Mounting storage: $mount"
            dokku storage:mount "$DOKKU_APP" "$mount"
        fi
    done <<< "$INPUT_STORAGE_MOUNTS"
fi

# Mount read-only storage volumes
if [ -n "$INPUT_READONLY_STORAGE_MOUNTS" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Replace {STORAGE_DIR} token with actual path
        mount="${line//\{STORAGE_DIR\}/$STORAGE_DIR}"
        readonly_mount="${mount}:ro"
        container_path="${mount#*:}"

        if ! dokku storage:list "$DOKKU_APP" | grep -q "$container_path"; then
            info "Mounting read-only storage: $readonly_mount"
            dokku storage:mount "$DOKKU_APP" "$readonly_mount"
        fi
    done <<< "$INPUT_READONLY_STORAGE_MOUNTS"
fi

info "Setting up Git remote for Dokku"
git remote add dokku dokku@"${DOKKU_HOST}":"$DOKKU_APP"

success "Preview environment setup complete"
