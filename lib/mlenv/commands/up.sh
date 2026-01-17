#!/usr/bin/env bash
# MLEnv Up Command
# Version: 2.1.0 - Context-based and security hardened

# Source dependencies
source "${MLENV_LIB}/utils/cleanup.sh"
source "${MLENV_LIB}/utils/command-helpers.sh"
source "${MLENV_LIB}/utils/retry.sh"
source "${MLENV_LIB}/utils/resource-tracker.sh"
source "${MLENV_LIB}/resource/admission.sh"

cmd_up() {
    # Initialize context
    declare -A ctx
    if ! cmd_init_context ctx; then
        error_with_help "Failed to initialize context" "invalid_argument"
        return 1
    fi
    
    # Initialize cleanup system for transactional behavior
    cleanup_init
    
    # Initialize resource tracking
    resource_tracking_init
    
    # Extract context values
    local container_name="${ctx[container_name]}"
    local workdir="${ctx[workdir]}"
    local log_dir="${ctx[log_dir]}"
    local image="${ctx[image]}"
    local requirements_path="${ctx[requirements_path]}"
    local run_as_user="${ctx[run_as_user]}"
    local ports="${ctx[ports]}"
    local gpu_devices="${ctx[gpu_devices]}"
    
    # Use effective config for image if not set
    if [[ -z "$image" ]]; then
        image=$(config_get_effective "container.default_image" "nvcr.io/nvidia/pytorch:25.12-py3")
    fi
    
    # Validate prerequisites
    if ! cmd_require_container_env; then
        cleanup_disable
        return 1
    fi
    
    # Admission control check (if enabled)
    if admission_is_enabled; then
        if ! admission_check_container_creation "$container_name" "$memory_limit" "$cpu_limit" "$gpu_devices"; then
            cleanup_disable
            return 1
        fi
    fi
    
    if ! cmd_validate_workspace "$workdir"; then
        cleanup_disable
        return 1
    fi
    
    # Validate container and image names
    if ! cmd_validate_container_name "$container_name"; then
        cleanup_disable
        return 1
    fi
    
    # Ensure log directory exists for container operations
    if ! cmd_ensure_directory "$log_dir" "Log directory"; then
        cleanup_disable
        return 1
    fi
    
    vlog "Configuration:"
    vlog "  Image: $image"
    vlog "  Container: $container_name"
    vlog "  Workdir: $workdir"
    vlog "  GPUs: ${gpu_devices:-all}"
    
    local status=$(container_get_status "$container_name")
    
    case "$status" in
        running)
            info "Container already running"
            cleanup_disable  # No cleanup needed
            ;;
        stopped)
            log "▶ Starting existing container"
            if ! container_start "$container_name"; then
                cleanup_disable
                error_with_help "Failed to start container" "container_error"
                return 1
            fi
            success "Container started"
            cleanup_disable  # No cleanup needed for restart
            ;;
        absent)
            # Check for container name collision (prevents race conditions)
            if ! container_check_collision "$container_name"; then
                cleanup_disable
                error_with_help "Container name collision detected" "container_exists"
                return 1
            fi
            
            # Validate image name
            if ! cmd_validate_image_name "$image"; then
                cleanup_disable
                return 1
            fi
            
            # Pull image if needed (with retry for network failures)
            if ! image_exists "$image"; then
                log "▶ Pulling image: $image"
                info "This may take a few minutes on first run..."
                
                # Retry image pull up to 3 times with exponential backoff
                local max_pull_attempts="${MLENV_IMAGE_PULL_RETRIES:-3}"
                if ! retry_with_backoff "$max_pull_attempts" 2 image_pull "$image"; then
                    cleanup_disable
                    error_with_help "Failed to pull image after $max_pull_attempts attempts: $image" "image_pull_error"
                    info "This may be due to network issues or invalid image name"
                    return 1
                fi
                success "Image pulled successfully"
            fi
            
            # Create init script if running as user
            if [[ "$run_as_user" == "true" ]]; then
                container_create_init_script "$log_dir"
                cleanup_register "rm -f '$log_dir/init.sh'"
                resource_track temp_file "$log_dir/init.sh"
            fi
            
            # Create devcontainer config
            if [[ "$(config_get_effective 'devcontainer.auto_generate' 'true')" == "true" ]]; then
                devcontainer_create_config "$workdir"
                cleanup_register "rm -rf '$workdir/.devcontainer'"
                resource_track temp_dir "$workdir/.devcontainer"
            fi
            
            log "▶ Creating container: $container_name"
            
            # Build container args (still uses globals for compatibility)
            # TODO: Refactor container_build_run_args to accept context
            readarray -t container_args < <(container_build_run_args "$container_name" "$image" "$workdir")
            
            # Reserve GPUs if specified
            if [[ -n "$gpu_devices" ]] && [[ "$gpu_devices" != "all" ]]; then
                if ! gpu_reserve "$gpu_devices" "$container_name"; then
                    cleanup_disable
                    error_with_help "Failed to reserve GPUs" "gpu_reservation_error"
                    return 1
                fi
                cleanup_register "gpu_release '$container_name'"
                resource_track gpu "$gpu_devices"
            fi
            
            # Create container via adapter
            if container_create "$container_name" "${container_args[@]}"; then
                cleanup_register "container_remove '$container_name'"
                success "Container created and started"
            else
                error_with_help "Failed to create container. Check logs: mlenv logs" "container_error"
                return 1  # Cleanup will be triggered automatically
            fi
            
            # Wait for container to be ready
            sleep 1
            
            # Install requirements if specified
            if [[ -n "$requirements_path" ]]; then
                if ! cmd_require_file "$requirements_path" "Requirements file"; then
                    return 1  # Cleanup will be triggered automatically
                fi
                
                # Temporarily set global for install_requirements compatibility
                # TODO: Refactor install_requirements to accept context
                REQUIREMENTS_PATH="$requirements_path"
                
                if ! install_requirements; then
                    error_with_help "Failed to install requirements" "requirements_error"
                    return 1  # Cleanup will be triggered automatically
                fi
            fi
            
            # Success - clear cleanup actions and untrack resources
            cleanup_clear
            cleanup_disable
            
            # Untrack successfully created resources
            resource_untrack temp_file "$log_dir/init.sh"
            resource_untrack temp_dir "$workdir/.devcontainer"
            resource_tracking_disable
            ;;
    esac
    
    success "Environment ready"
    if [[ -n "$ports" ]]; then
        info "Ports forwarded: $ports"
    fi
    info "Enter with: mlenv exec"
    
    return 0
}
