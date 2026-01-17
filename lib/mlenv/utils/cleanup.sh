#!/usr/bin/env bash
# MLEnv Cleanup Trap System
# Version: 2.1.0 - Security hardened
# Provides rollback on failure for transactional operations

# Global cleanup stack
declare -a MLENV_CLEANUP_STACK=()
declare MLENV_CLEANUP_ENABLED=false

# Validate cleanup action is safe
# Only allows specific patterns for cleanup operations
_cleanup_validate_action() {
    local action="$1"
    
    # Allow empty actions (skip)
    if [[ -z "$action" ]]; then
        return 1
    fi
    
    # Allowed patterns (whitelist approach):
    # - rm -f /path/to/file
    # - docker rm -f container_name
    # - podman rm -f container_name
    # - container_remove 'name'
    # - image_remove_if_not_used 'image'
    # - Function calls with quoted args
    
    # Check for dangerous patterns (blacklist)
    if echo "$action" | grep -qE '\$\(|`|;|\||&|\{|\}'; then
        warn "Cleanup action contains dangerous patterns: $action"
        return 1
    fi
    
    # Whitelist: rm -f, docker/podman rm, or known function calls
    if [[ "$action" =~ ^(rm[[:space:]]+-f|docker[[:space:]]+rm|podman[[:space:]]+rm|container_remove|image_remove_if_not_used) ]]; then
        return 0
    fi
    
    # Unknown pattern - reject for safety
    warn "Cleanup action doesn't match safe patterns: $action"
    return 1
}

# Register cleanup action
# Actions are validated before registration
cleanup_register() {
    local action="$1"
    
    # Validate action is safe
    if ! _cleanup_validate_action "$action"; then
        warn "Skipping unsafe cleanup action: $action"
        return 1
    fi
    
    MLENV_CLEANUP_STACK+=("$action")
    vlog "Registered cleanup: $action"
    return 0
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
