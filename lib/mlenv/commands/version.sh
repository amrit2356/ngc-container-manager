#!/usr/bin/env bash
# MLEnv Version Command
# Version: 2.1.0 - Context-based

# Source command helpers
source "${MLENV_LIB}/utils/command-helpers.sh"

cmd_version() {
    # Initialize context
    declare -A ctx
    cmd_init_context ctx || return 1
    
    # Get version from context
    local version="${ctx[version]}"
    
    echo "MLEnv - ML Environment Manager v${version}"
    return 0
}
