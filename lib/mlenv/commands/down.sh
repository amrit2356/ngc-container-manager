#!/usr/bin/env bash
# MLEnv Down Command
# Version: 2.0.0

cmd_down() {
    if container_is_running "$CONTAINER_NAME"; then
        log "■ Stopping container"
        container_stop "$CONTAINER_NAME"
        success "Container stopped"
    else
        info "Container not running"
    fi
}
