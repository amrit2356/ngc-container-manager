#!/usr/bin/env bash
# MLEnv Up Command
# Version: 2.0.0

cmd_up() {
    vlog "Configuration:"
    vlog "  Image: ${IMAGE:-$MLENV_DEFAULT_IMAGE}"
    vlog "  Container: $CONTAINER_NAME"
    vlog "  Workdir: $WORKDIR"
    vlog "  GPUs: ${GPU_DEVICES:-$MLENV_GPU_DEVICES}"
    
    local status=$(container_get_status "$CONTAINER_NAME")
    
    case "$status" in
        running)
            info "Container already running"
            ;;
        stopped)
            log "▶ Starting existing container"
            container_start "$CONTAINER_NAME"
            success "Container started"
            ;;
        absent)
            local image="${IMAGE:-$MLENV_DEFAULT_IMAGE}"
            
            # Pull image if needed
            if ! image_exists "$image"; then
                image_pull "$image"
            fi
            
            # Create init script if running as user
            if [[ "$RUN_AS_USER" == "true" ]]; then
                container_create_init_script "$LOG_DIR"
            fi
            
            # Create devcontainer config
            if [[ "$(config_get 'devcontainer.auto_generate' 'true')" == "true" ]]; then
                devcontainer_create_config "$WORKDIR"
            fi
            
            log "▶ Creating container: $CONTAINER_NAME"
            
            # Build container args
            readarray -t container_args < <(container_build_run_args "$CONTAINER_NAME" "$image" "$WORKDIR")
            
            # Create container via adapter
            if container_create "$CONTAINER_NAME" "${container_args[@]}"; then
                success "Container created and started"
            else
                die "Failed to create container. Check logs: mlenv logs"
            fi
            ;;
    esac
    
    # Wait for container to be ready
    sleep 1
    
    # Install requirements if specified
    install_requirements
    
    success "Environment ready"
    if [[ -n "$PORTS" ]]; then
        info "Ports forwarded: $PORTS"
    fi
    info "Enter with: mlenv exec"
}
