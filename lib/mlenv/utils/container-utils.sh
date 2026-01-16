#!/usr/bin/env bash
# MLEnv Container Utilities
# Version: 2.0.0

# Install requirements in container
install_requirements() {
    if [[ -z "$REQUIREMENTS_PATH" ]]; then
        return 0
    fi
    
    local rel_path
    rel_path="$(realpath --relative-to="$WORKDIR" "$REQUIREMENTS_PATH")"
    
    # Check if already installed (unless force flag is set)
    if [[ "$FORCE_REQUIREMENTS" == "false" ]] && [[ -f "$REQUIREMENTS_MARKER" ]]; then
        local marker_content
        marker_content="$(cat "$REQUIREMENTS_MARKER")"
        local current_hash
        current_hash="$(md5sum "$REQUIREMENTS_PATH" | cut -d' ' -f1)"
        
        if [[ "$marker_content" == "$current_hash" ]]; then
            info "Requirements already installed (use --force-requirements to reinstall)"
            return 0
        fi
    fi
    
    log "▶ Installing requirements from: $rel_path"
    
    # Run pip as the user, not root
    if [[ "$RUN_AS_USER" == "true" ]]; then
        local user_uid="$(id -u)"
        if docker exec --user "${user_uid}" "$CONTAINER_NAME" bash -c \
            "pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir -r '/workspace/$rel_path'" >> "$LOG_FILE" 2>&1; then
            md5sum "$REQUIREMENTS_PATH" | cut -d' ' -f1 > "$REQUIREMENTS_MARKER"
            success "Requirements installed"
        else
            die "Failed to install requirements. Check logs: mlenv logs"
        fi
    else
        if docker exec "$CONTAINER_NAME" bash -c \
            "pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir -r '/workspace/$rel_path'" >> "$LOG_FILE" 2>&1; then
            md5sum "$REQUIREMENTS_PATH" | cut -d' ' -f1 > "$REQUIREMENTS_MARKER"
            success "Requirements installed"
        else
            die "Failed to install requirements. Check logs: mlenv logs"
        fi
    fi
}
