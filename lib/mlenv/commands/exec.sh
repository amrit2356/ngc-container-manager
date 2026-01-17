#!/usr/bin/env bash
# MLEnv Exec Command
# Version: 2.0.0

cmd_exec() {
    # Create context from global state
    declare -A ctx
    mlenv_context_create ctx
    
    if ! mlenv_context_validate ctx; then
        die "Invalid context"
    fi
    
    local container_name="${ctx[container_name]}"
    local run_as_user="${ctx[run_as_user]}"
    local exec_cmd="${ctx[exec_cmd]}"
    
    if ! container_is_running "$container_name"; then
        error "Container not running: $container_name"
        info "Start the container with: mlenv up"
        exit 1
    fi
    
    # Determine user for exec
    local exec_user=""
    if [[ "$run_as_user" == "true" ]]; then
        exec_user="--user $(id -u):$(id -g)"
    fi
    
    if [[ -n "$exec_cmd" ]]; then
        # Execute specific command (no -t flag, only stdin)
        vlog "Executing command: $exec_cmd"
        docker exec $exec_user "$container_name" bash -c "$exec_cmd"
    else
        # Interactive bash (needs -it for terminal)
        docker exec -it $exec_user "$container_name" bash
    fi
}
