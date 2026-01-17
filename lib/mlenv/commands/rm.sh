#!/usr/bin/env bash
# MLEnv Remove Command
# Version: 2.1.0

# Source dependencies
source "${MLENV_LIB}/utils/command-helpers.sh"
source "${MLENV_LIB}/core/gpu.sh"

cmd_rm() {
    # Initialize context
    declare -A ctx
    if ! cmd_init_context ctx; then
        error_with_help "Failed to initialize context" "invalid_argument"
        return 1
    fi
    
    local container_name="${ctx[container_name]}"
    local log_dir="${ctx[log_dir]}"
    local requirements_marker="${ctx[requirements_marker]}"
    
    if container_exists "$container_name"; then
        log "✖ Removing container: $container_name (your code on host is safe)"
        
        # Release GPU reservations before removing container
        gpu_release "$container_name"
        
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
