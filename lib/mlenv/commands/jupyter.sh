#!/usr/bin/env bash
# MLEnv Jupyter Command
# Version: 2.0.0

cmd_jupyter() {
    # Create context from global state
    declare -A ctx
    mlenv_context_create ctx
    
    if ! mlenv_context_validate ctx; then
        die "Invalid context"
    fi
    
    local container_name="${ctx[container_name]}"
    local workdir="${ctx[workdir]}"
    local requirements_path="${ctx[requirements_path]}"
    local ports="${ctx[ports]}"
    local jupyter_port="${ctx[jupyter_port]}"
    
    # Docker and GPU checks
    if ! validate_docker; then
        die "Docker validation failed"
    fi
    
    if ! docker info 2>/dev/null | grep -q "Runtimes:.*nvidia"; then
        die "NVIDIA Container Toolkit not detected. Install from https://github.com/NVIDIA/nvidia-container-toolkit"
    fi
    
    # Determine which port to use (default to 8888 if not specified)
    local container_port="${jupyter_port:-8888}"
    local default_ports="${container_port}:${container_port}"
    local host_port=""
    
    # Check container status
    local status=$(container_get_status "$container_name")
    
    case "$status" in
        absent)
            # Container doesn't exist - create it with port forwarding
            log "▶ Container not found. Creating with Jupyter port forwarding..."
            
            # Auto-detect requirements.txt if it exists and wasn't specified
            if [[ -z "$requirements_path" ]] && [[ -f "$workdir/requirements.txt" ]]; then
                requirements_path="$workdir/requirements.txt"
                REQUIREMENTS_PATH="$requirements_path"  # Update global for cmd_up
                info "Auto-detected requirements.txt"
            fi
            
            # Set default port forwarding if not already set
            if [[ -z "$ports" ]]; then
                # Find an available port automatically
                local available_port
                available_port=$(find_available_port "$container_port")
                
                if [[ -n "$available_port" ]]; then
                    if [[ "$available_port" != "$container_port" ]]; then
                        warn "Port $container_port is busy. Using port $available_port instead."
                        container_port="$available_port"  # Update container port to match
                    fi
                    ports="${available_port}:${available_port}"  # Map both sides to same port
                    PORTS="$ports"  # Update global for cmd_up
                    info "Using port forwarding: $ports"
                else
                    die "Could not find an available port in range ${container_port}-8999"
                fi
            fi
            
            # Export for container creation
            export MLENV_PORTS="$PORTS"
            
            # Create and start the container
            cmd_up
            ;;
            
        stopped|running)
            # Container exists - check if it has proper port forwarding
            vlog "Checking port forwarding on existing container..."
            
            # Check if the container has the required port forwarding (using direct docker inspect like v1.1.0)
            local has_port=false
            local existing_ports
            existing_ports=$(docker inspect "$CONTAINER_NAME" 2>/dev/null | \
                jq -r '.[0].NetworkSettings.Ports | to_entries[] | select(.value != null) | .key' 2>/dev/null || true)
            
            if [[ -n "$existing_ports" ]]; then
                # Check if our target port is in there
                if echo "$existing_ports" | grep -q "^${container_port}/tcp$"; then
                    has_port=true
                fi
            fi
            
            if [[ "$has_port" == "false" ]]; then
                # Container exists but doesn't have the required port
                echo ""
                warn "Container exists but port $container_port is not forwarded"
                info "Docker doesn't allow adding ports to existing containers"
                echo ""
                
                # Auto-detect requirements.txt if it exists and wasn't specified
                if [[ -z "$REQUIREMENTS_PATH" ]] && [[ -f "$WORKDIR/requirements.txt" ]]; then
                    REQUIREMENTS_PATH="$WORKDIR/requirements.txt"
                    info "Auto-detected requirements.txt for recreation"
                fi
                
                # Remove the old container
                log "▶ Removing old container..."
                cmd_rm
                
                # Set port forwarding for recreation - find available port
                if [[ -z "$PORTS" ]]; then
                    local available_port
                    available_port=$(find_available_port "$container_port")
                    
                    if [[ -n "$available_port" ]]; then
                        if [[ "$available_port" != "$container_port" ]]; then
                            warn "Port $container_port is busy. Using port $available_port instead."
                            container_port="$available_port"  # Update container port to match
                        fi
                        PORTS="${available_port}:${available_port}"  # Map both sides to same port
                        info "Recreating container with port forwarding: $PORTS"
                    else
                        die "Could not find an available port in range ${container_port}-8999"
                    fi
                fi
                
                # Export for container creation
                export MLENV_PORTS="$PORTS"
                
                # Recreate with port forwarding
                log "▶ Creating new container..."
                cmd_up
                # Give container a moment to fully initialize
                sleep 2
            else
                # Port is forwarded, just ensure container is running
                if [[ "$status" == "stopped" ]]; then
                    log "▶ Starting existing container"
                    docker start "$CONTAINER_NAME" >> "$LOG_FILE" 2>&1
                    success "Container started"
                    sleep 1
                else
                    vlog "Container already running with proper port forwarding"
                fi
            fi
            ;;
    esac
    
    # Now container is running with proper ports - find the host port (matches v1.1.0 logic)
    if [[ -z "$JUPYTER_PORT" ]]; then
        # Try to auto-detect a suitable port from forwarded ports
        local forwarded_ports
        forwarded_ports=$(docker inspect "$CONTAINER_NAME" 2>/dev/null | \
            jq -r '.[0].NetworkSettings.Ports | to_entries[] | select(.value != null) | .key as $port | .value[] | "\(.HostPort):\($port | split("/")[0])"' 2>/dev/null || true)
        
        # Check for 8888 first
        if echo "$forwarded_ports" | grep -q ":8888$"; then
            container_port="8888"
        else
            # Check for 8889-8899
            for port in {8889..8899}; do
                if echo "$forwarded_ports" | grep -q ":${port}$"; then
                    container_port="$port"
                    break
                fi
            done
        fi
        
        if [[ -z "$container_port" ]]; then
            # This shouldn't happen after our setup above, but just in case
            die "Failed to detect Jupyter port after container setup"
        fi
        
        vlog "Auto-detected container port: $container_port"
    fi
    
    # Find the corresponding host port
    host_port=$(docker inspect "$CONTAINER_NAME" 2>/dev/null | \
        jq -r '.[0].NetworkSettings.Ports | to_entries[] | select(.value != null) | .key as $port | .value[] | "\(.HostPort):\($port | split("/")[0])"' 2>/dev/null | \
        grep ":${container_port}$" | cut -d: -f1 | head -1)
    
    if [[ -z "$host_port" ]]; then
        # This also shouldn't happen after our setup
        die "Failed to detect host port mapping after container setup"
    fi
    
    log "▶ Starting Jupyter Lab on container port $container_port"
    
    # Show access info
    echo ""
    success "Jupyter will be accessible at: http://localhost:$host_port"
    info "Token will be shown below..."
    echo ""
    
    # Run as user if user mapping is enabled
    local exec_user=""
    if [[ "$RUN_AS_USER" == "true" ]]; then
        exec_user="--user $(id -u):$(id -g)"
    fi
    
    docker exec -it $exec_user "$CONTAINER_NAME" bash -c "jupyter lab --ip=0.0.0.0 --port=$container_port --no-browser --allow-root"
}
