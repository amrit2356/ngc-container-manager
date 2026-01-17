#!/usr/bin/env bash
# MLEnv Down Command
# Version: 2.1.0

# Source dependencies
source "${MLENV_LIB}/utils/command-helpers.sh"

cmd_down() {
    # Initialize context
    declare -A ctx
    if ! cmd_init_context ctx; then
        error_with_help "Failed to initialize context" "invalid_argument"
        return 1
    fi
    
    local container_name="${ctx[container_name]}"
    
    if container_is_running "$container_name"; then
        log "■ Stopping container: $container_name"
        container_stop "$container_name"
        success "Container stopped"
    else
        info "Container not running"
    fi
}
