#!/usr/bin/env bash
# MLEnv Status Command
# Version: 2.0.0

cmd_status() {
    local status=$(container_get_status "$CONTAINER_NAME")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Container: $CONTAINER_NAME"
    echo "Status: $status"
    echo "Workdir: $WORKDIR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if container_exists "$CONTAINER_NAME"; then
        echo ""
        container_list "name=${CONTAINER_NAME}"
    fi
}
