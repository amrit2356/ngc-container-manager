#!/usr/bin/env bash
# MLEnv Logs Command
# Version: 2.1.0

# Source dependencies
source "${MLENV_LIB}/utils/command-helpers.sh"

cmd_logs() {
    # Initialize context
    declare -A ctx
    if ! cmd_init_context ctx; then
        error_with_help "Failed to initialize context" "invalid_argument"
        return 1
    fi
    
    local log_file="${ctx[log_file]}"
    
    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    else
        info "No logs found at: $log_file"
    fi
}
