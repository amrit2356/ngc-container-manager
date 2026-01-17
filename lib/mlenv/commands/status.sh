#!/usr/bin/env bash
# MLEnv Status Command
# Version: 2.0.0

cmd_status() {
    # Create context from global state (for now)
    declare -A ctx
    mlenv_context_create ctx
    
    # Validate context
    if ! mlenv_context_validate ctx; then
        die "Invalid context"
    fi
    
    # Use context variables instead of globals
    local container_name="${ctx[container_name]}"
    local workdir="${ctx[workdir]}"
    local status=$(container_get_status "$container_name")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Container: $container_name"
    echo "Status: $status"
    echo "Workdir: $workdir"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if container_exists "$container_name"; then
        echo ""
        container_list "name=${container_name}"
    fi
}
