#!/usr/bin/env bash
# MLEnv Exec Command
# Version: 2.1.0 - Security hardened

# Source sanitization utilities
source "${MLENV_LIB}/utils/sanitization.sh"

cmd_exec() {
    # Create context from global state
    declare -A ctx
    mlenv_context_create ctx
    
    if ! mlenv_context_validate ctx; then
        error_with_help "Invalid context" "invalid_argument"
        return 1
    fi
    
    local container_name="${ctx[container_name]}"
    local run_as_user="${ctx[run_as_user]}"
    local exec_cmd="${ctx[exec_cmd]}"
    
    # Validate container name (security check)
    if ! validate_container_name "$container_name"; then
        error_with_help "Invalid container name: $container_name" "invalid_argument"
        return 1
    fi
    
    if ! container_is_running "$container_name"; then
        error_with_help "Container not running: $container_name" "container_not_running"
        return 1
    fi
    
    # Determine user for exec
    local exec_user=""
    if [[ "$run_as_user" == "true" ]]; then
        exec_user="--user $(id -u):$(id -g)"
    fi
    
    if [[ -n "$exec_cmd" ]]; then
        # Execute specific command with security validation
        vlog "Validating command for safety: $exec_cmd"
        
        # SECURITY: Validate command is safe before execution
        if ! validate_safe_command "$exec_cmd"; then
            error_with_help "Unsafe command detected. Command contains dangerous characters." "invalid_argument"
            info "Dangerous patterns detected: shell metacharacters (;|&\`\$()), path traversal (../), or risky commands (rm -rf, sudo)"
            info "For complex commands, use: mlenv exec (interactive shell)"
            return 1
        fi
        
        vlog "Executing validated command: $exec_cmd"
        # Use safe execution wrapper
        safe_container_exec "$container_name" "$exec_user" bash -c "$exec_cmd" || {
            error_with_help "Command execution failed" "container_error"
            return 1
        }
    else
        # Interactive bash (inherently safe - no user input in command string)
        vlog "Opening interactive shell in container: $container_name"
        
        # Execute interactive shell
        # Note: Exit code from interactive shell is normal (user's last command or exit)
        # We only check if docker exec itself failed (container not found, etc)
        docker exec -it $exec_user "$container_name" bash
        local exit_code=$?
        
        # Only treat certain exit codes as actual errors (127 = command not found, 126 = not executable)
        # Exit codes 0-125 are from user's session and are normal
        if (( exit_code == 126 || exit_code == 127 )); then
            error_with_help "Failed to open interactive shell" "container_error"
            return 1
        fi
        
        # Return the user's exit code (allows scripts to check: mlenv exec && echo "success")
        return $exit_code
    fi
}
