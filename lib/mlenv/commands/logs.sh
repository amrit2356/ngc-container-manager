#!/usr/bin/env bash
# MLEnv Logs Command
# Version: 2.0.0

cmd_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        cat "$LOG_FILE"
    else
        info "No logs found"
    fi
}
