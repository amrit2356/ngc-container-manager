#!/usr/bin/env bash
# MLEnv Up Command
# Version: 2.0.0

cmd_up() {
    # Source cleanup utilities
    source "${MLENV_LIB}/utils/cleanup.sh"
    
    # Initialize cleanup system for transactional behavior
    cleanup_init
    
    # Validate prerequisites
    if ! validate_docker; then
        cleanup_disable
        die "Docker validation failed"
    fi
    
    if ! validate_workspace "$WORKDIR"; then
        cleanup_disable
        die "Workspace validation failed"
    fi
    
    # Ensure log directory exists for container operations
    mkdir -p "$LOG_DIR"
    
    vlog "Configuration:"
    vlog "  Image: ${IMAGE:-$MLENV_DEFAULT_IMAGE}"
    vlog "  Container: $CONTAINER_NAME"
    vlog "  Workdir: $WORKDIR"
    vlog "  GPUs: ${GPU_DEVICES:-$MLENV_GPU_DEVICES}"
    
    local status=$(container_get_status "$CONTAINER_NAME")
    
    case "$status" in
        running)
            info "Container already running"
            cleanup_disable  # No cleanup needed
            ;;
        stopped)
            log "▶ Starting existing container"
            if ! container_start "$CONTAINER_NAME"; then
                cleanup_disable
                die "Failed to start container"
            fi
            success "Container started"
            cleanup_disable  # No cleanup needed for restart
            ;;
        absent)
            local image="${IMAGE:-$MLENV_DEFAULT_IMAGE}"
            
            # Validate image name
            if ! validate_image_name "$image"; then
                cleanup_disable
                die "Invalid image name: $image"
            fi
            
            # Pull image if needed
            if ! image_exists "$image"; then
                log "▶ Pulling image: $image"
                if ! image_pull "$image"; then
                    cleanup_disable
                    die "Failed to pull image: $image"
                fi
            fi
            
            # Create init script if running as user
            if [[ "$RUN_AS_USER" == "true" ]]; then
                container_create_init_script "$LOG_DIR"
                cleanup_register "rm -f '$LOG_DIR/init.sh'"
            fi
            
            # Create devcontainer config
            if [[ "$(config_get_effective 'devcontainer.auto_generate' 'true')" == "true" ]]; then
                devcontainer_create_config "$WORKDIR"
                cleanup_register "rm -rf '$WORKDIR/.devcontainer'"
            fi
            
            log "▶ Creating container: $CONTAINER_NAME"
            
            # Build container args
            readarray -t container_args < <(container_build_run_args "$CONTAINER_NAME" "$image" "$WORKDIR")
            
            # Create container via adapter
            if container_create "$CONTAINER_NAME" "${container_args[@]}"; then
                cleanup_register "container_remove '$CONTAINER_NAME' 2>/dev/null || true"
                success "Container created and started"
            else
                die "Failed to create container. Check logs: mlenv logs"
            fi
            
            # Wait for container to be ready
            sleep 1
            
            # Install requirements if specified
            if [[ -n "$REQUIREMENTS_PATH" ]]; then
                if ! validate_requirements_file "$REQUIREMENTS_PATH"; then
                    die "Requirements file validation failed"
                fi
                
                if ! install_requirements; then
                    die "Failed to install requirements"
                fi
            fi
            
            # Success - clear cleanup actions
            cleanup_clear
            cleanup_disable
            ;;
    esac
    
    success "Environment ready"
    if [[ -n "$PORTS" ]]; then
        info "Ports forwarded: $PORTS"
    fi
    info "Enter with: mlenv exec"
}
