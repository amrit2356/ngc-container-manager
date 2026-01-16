#!/usr/bin/env bash
# MLEnv Exec Command
# Version: 2.0.0

cmd_exec() {
    if ! container_is_running "$CONTAINER_NAME"; then
        die "Container not running. Start with: mlenv up"
    fi
    
    # Determine user for exec
    local exec_user=""
    if [[ "$RUN_AS_USER" == "true" ]]; then
        exec_user="--user $(id -u):$(id -g)"
    fi
    
    if [[ -n "$EXEC_CMD" ]]; then
        # Execute specific command (no -t flag, only stdin)
        vlog "Executing command: $EXEC_CMD"
        docker exec $exec_user "$CONTAINER_NAME" bash -c "$EXEC_CMD"
    else
        # Interactive bash (needs -it for terminal)
        docker exec -it $exec_user "$CONTAINER_NAME" bash
    fi
}
