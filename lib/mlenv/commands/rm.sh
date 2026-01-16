#!/usr/bin/env bash
# MLEnv Remove Command
# Version: 2.0.0

cmd_rm() {
    if container_exists "$CONTAINER_NAME"; then
        log "✖ Removing container (your code on host is safe)"
        container_remove "$CONTAINER_NAME"
        
        # Clean up markers and init script
        rm -f "$REQUIREMENTS_MARKER"
        rm -f "${LOG_DIR}/init.sh"
        
        success "Container removed"
    else
        info "Container does not exist"
    fi
}
