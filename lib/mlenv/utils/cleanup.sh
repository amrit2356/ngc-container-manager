#!/usr/bin/env bash
# MLEnv Cleanup Trap System
# Version: 2.0.0
# Provides rollback on failure for transactional operations

# Global cleanup stack
declare -a MLENV_CLEANUP_STACK=()
declare MLENV_CLEANUP_ENABLED=false

# Register cleanup action
cleanup_register() {
    local action="$1"
    MLENV_CLEANUP_STACK+=("$action")
    vlog "Registered cleanup: $action"
}

# Execute all cleanup actions (LIFO order)
cleanup_execute() {
    local exit_code=$?
    
    if [[ "$MLENV_CLEANUP_ENABLED" != "true" ]]; then
        return 0
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        vlog "Success - skipping cleanup"
        return 0
    fi
    
    warn "Failure detected (exit $exit_code) - executing cleanup..."
    
    # Execute in reverse order (LIFO - Last In First Out)
    for ((i=${#MLENV_CLEANUP_STACK[@]}-1; i>=0; i--)); do
        local action="${MLENV_CLEANUP_STACK[i]}"
        vlog "Cleanup: $action"
        if eval "$action" 2>/dev/null; then
            vlog "  ✓ Cleanup action succeeded"
        else
            warn "  ✗ Cleanup action failed: $action"
        fi
    done
    
    MLENV_CLEANUP_STACK=()
    info "Cleanup complete"
}

# Clear cleanup stack (on success)
cleanup_clear() {
    MLENV_CLEANUP_STACK=()
    vlog "Cleanup stack cleared"
}

# Initialize cleanup system
cleanup_init() {
    MLENV_CLEANUP_ENABLED=true
    MLENV_CLEANUP_STACK=()
    trap cleanup_execute EXIT ERR
    vlog "Cleanup trap system initialized"
}

# Disable cleanup system
cleanup_disable() {
    MLENV_CLEANUP_ENABLED=false
    trap - EXIT ERR
    vlog "Cleanup trap system disabled"
}

# Get cleanup stack size
cleanup_stack_size() {
    echo "${#MLENV_CLEANUP_STACK[@]}"
}

# Print cleanup stack (for debugging)
cleanup_print_stack() {
    local size="${#MLENV_CLEANUP_STACK[@]}"
    
    if [[ $size -eq 0 ]]; then
        echo "Cleanup stack is empty"
        return
    fi
    
    echo "Cleanup stack ($size actions):"
    for ((i=0; i<$size; i++)); do
        echo "  $((i+1)). ${MLENV_CLEANUP_STACK[i]}"
    done
}
