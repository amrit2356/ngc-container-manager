#!/usr/bin/env bash
# Authentication Manager Port (Interface)
# Version: 2.0.0

# Define the interface contract
declare -A AUTH_PORT_METHODS=(
    [login]="auth_registry_login"
    [logout]="auth_registry_logout"
    [is_authenticated]="auth_registry_is_authenticated"
    [get_credentials]="auth_registry_get_credentials"
)

# Validate that an adapter implements all required methods
auth_port_validate_adapter() {
    local adapter="$1"
    local missing=()
    
    for method in "${AUTH_PORT_METHODS[@]}"; do
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

auth_registry_login() {
    if [[ -z "$MLENV_ACTIVE_REGISTRY_ADAPTER" ]]; then
        die "No registry adapter loaded"
    fi
    "${MLENV_ACTIVE_REGISTRY_ADAPTER}_auth_registry_login" "$@"
}

auth_registry_logout() {
    if [[ -z "$MLENV_ACTIVE_REGISTRY_ADAPTER" ]]; then
        die "No registry adapter loaded"
    fi
    "${MLENV_ACTIVE_REGISTRY_ADAPTER}_auth_registry_logout" "$@"
}

auth_registry_is_authenticated() {
    if [[ -z "$MLENV_ACTIVE_REGISTRY_ADAPTER" ]]; then
        die "No registry adapter loaded"
    fi
    "${MLENV_ACTIVE_REGISTRY_ADAPTER}_auth_registry_is_authenticated" "$@"
}

auth_registry_get_credentials() {
    if [[ -z "$MLENV_ACTIVE_REGISTRY_ADAPTER" ]]; then
        die "No registry adapter loaded"
    fi
    "${MLENV_ACTIVE_REGISTRY_ADAPTER}_auth_registry_get_credentials" "$@"
}
