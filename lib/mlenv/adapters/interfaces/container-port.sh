#!/usr/bin/env bash
# Container Manager Port (Interface)
# Version: 2.0.0

# Define the interface contract
declare -A CONTAINER_PORT_METHODS=(
    [create]="container_create"
    [start]="container_start"
    [stop]="container_stop"
    [remove]="container_remove"
    [exec]="container_exec"
    [inspect]="container_inspect"
    [list]="container_list"
    [logs]="container_logs"
    [exists]="container_exists"
    [is_running]="container_is_running"
    [get_forwarded_ports]="container_get_forwarded_ports"
)

# Validate that an adapter implements all required methods
container_port_validate_adapter() {
    local adapter="$1"
    local missing=()
    
    for method in "${CONTAINER_PORT_METHODS[@]}"; do
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
# These functions will be replaced by adapter-specific implementations

container_create() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_create" "$@"
}

container_start() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_start" "$@"
}

container_stop() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_stop" "$@"
}

container_remove() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_remove" "$@"
}

container_exec() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_exec" "$@"
}

container_inspect() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_inspect" "$@"
}

container_list() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_list" "$@"
}

container_logs() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_logs" "$@"
}

container_exists() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_exists" "$@"
}

container_is_running() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_is_running" "$@"
}

container_get_forwarded_ports() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_get_forwarded_ports" "$@"
}

# Get container stats
container_stats() {
    if [[ -z "$MLENV_ACTIVE_CONTAINER_ADAPTER" ]]; then
        die "No container adapter loaded"
    fi
    "${MLENV_ACTIVE_CONTAINER_ADAPTER}_container_stats" "$@"
}
