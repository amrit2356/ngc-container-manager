#!/usr/bin/env bash
# MLEnv Status Command
# Version: 2.1.0

# Source dependencies
source "${MLENV_LIB}/utils/command-helpers.sh"

cmd_status() {
    # Initialize context
    declare -A ctx
    if ! cmd_init_context ctx; then
        error_with_help "Failed to initialize context" "invalid_argument"
        return 1
    fi
    
    # Use context variables
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
