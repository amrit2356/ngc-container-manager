#!/usr/bin/env bash
# MLEnv Restart Command
# Version: 2.1.0

# Source dependencies
source "${MLENV_LIB}/utils/command-helpers.sh"

cmd_restart() {
    # Initialize context
    declare -A ctx
    if ! cmd_init_context ctx; then
        error_with_help "Failed to initialize context" "invalid_argument"
        return 1
    fi
    
    local container_name="${ctx[container_name]}"
    
    info "🔄 Restarting container: $container_name"
    
    cmd_down
    sleep 1
    cmd_up
}
