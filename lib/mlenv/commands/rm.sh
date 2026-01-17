#!/usr/bin/env bash
# MLEnv Remove Command
# Version: 2.0.0

cmd_rm() {
    # Create context from global state
    declare -A ctx
    mlenv_context_create ctx
    
    if ! mlenv_context_validate ctx; then
        die "Invalid context"
    fi
    
    local container_name="${ctx[container_name]}"
    local log_dir="${ctx[log_dir]}"
    local requirements_marker="${ctx[requirements_marker]}"
    
    if container_exists "$container_name"; then
        log "✖ Removing container: $container_name (your code on host is safe)"
        container_remove "$container_name"
        
        # Clean up markers and init script
        if [[ -d "$log_dir" ]]; then
            rm -f "$requirements_marker"
            rm -f "${log_dir}/init.sh"
        fi
        
        success "Container removed"
    else
        info "Container does not exist"
    fi
}
