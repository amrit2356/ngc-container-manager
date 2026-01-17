#!/usr/bin/env bash
# Image Manager Port (Interface)
# Version: 2.0.0

# Define the interface contract
declare -A IMAGE_PORT_METHODS=(
    [pull]="image_pull"
    [push]="image_push"
    [list]="image_list"
    [remove]="image_remove"
    [inspect]="image_inspect"
    [tag]="image_tag"
    [exists]="image_exists"
)

# Validate that an adapter implements all required methods
image_port_validate_adapter() {
    local adapter="$1"
    local missing=()
    
    for method in "${IMAGE_PORT_METHODS[@]}"; do
        if ! declare -f "${adapter}_${method}" >/dev/null 2>&1; then
            missing+=("$method")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Adapter '$adapter' missing required methods: ${missing[*]}"
        return 1
    fi
    
    vlog "Adapter '$adapter' validated successfully"
    return 0
}

# Port interface - delegates to active adapter

image_pull() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_image_pull" "$@"
}

image_push() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_image_push" "$@"
}

image_list() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_image_list" "$@"
}

image_remove() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_image_remove" "$@"
}

image_inspect() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_image_inspect" "$@"
}

image_tag() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_image_tag" "$@"
}

image_exists() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_image_exists" "$@"
}
