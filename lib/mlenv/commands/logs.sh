#!/usr/bin/env bash
# MLEnv Logs Command
# Version: 2.0.0

cmd_logs() {
    # Create context from global state
    declare -A ctx
    mlenv_context_create ctx
    
    local log_file="${ctx[log_file]}"
    
    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    else
        info "No logs found at: $log_file"
    fi
}
