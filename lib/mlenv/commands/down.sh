#!/usr/bin/env bash
# MLEnv Down Command
# Version: 2.0.0

cmd_down() {
    # Create context from global state
    declare -A ctx
    mlenv_context_create ctx
    
    if ! mlenv_context_validate ctx; then
        die "Invalid context"
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
