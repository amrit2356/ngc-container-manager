#!/usr/bin/env bash
# MLEnv Container Core Logic
# Version: 2.0.0

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/utils/validation.sh"

# Container state management
container_get_status() {
    local container_name="$1"
    
    if container_exists "$container_name"; then
        if container_is_running "$container_name"; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "absent"
    fi
}

# Build Docker run arguments (extracted from original)
container_build_run_args() {
    local container_name="$1"
    local image="$2"
    local workdir="$3"
    shift 3
    local options=("$@")
    
    local args=()
    
    # Base configuration
    args+=("--name" "$container_name")
    args+=("-d")
    args+=("--restart" "${MLENV_RESTART_POLICY:-unless-stopped}")
    
    # GPU configuration
    local gpu_devices="${MLENV_GPU_DEVICES:-all}"
    if [[ "$gpu_devices" == "all" ]]; then
        args+=("--gpus" "all")
    else
        args+=("--gpus" "device=${gpu_devices}")
    fi
    
    # Memory and performance
    args+=("--shm-size=${MLENV_SHM_SIZE:-16g}")
    args+=("--ulimit" "memlock=-1")
    args+=("--ulimit" "stack=67108864")
    
    # Resource limits
    if [[ -n "${MLENV_MEMORY_LIMIT:-}" ]]; then
        args+=("--memory" "$MLENV_MEMORY_LIMIT")
        vlog "Memory limit: $MLENV_MEMORY_LIMIT"
    fi
    
    if [[ -n "${MLENV_CPU_LIMIT:-}" ]]; then
        args+=("--cpus" "$MLENV_CPU_LIMIT")
        vlog "CPU limit: $MLENV_CPU_LIMIT"
    fi
    
    # Port forwarding
    if [[ -n "${MLENV_PORTS:-}" ]]; then
        IFS=',' read -ra PORT_ARRAY <<< "$MLENV_PORTS"
        for port in "${PORT_ARRAY[@]}"; do
            args+=("-p" "$port")
            vlog "Forwarding port: $port"
        done
    fi
    
    # Environment file
    if [[ -n "${MLENV_ENV_FILE:-}" ]] && [[ -f "$MLENV_ENV_FILE" ]]; then
        args+=("--env-file" "$MLENV_ENV_FILE")
        vlog "Using env file: $MLENV_ENV_FILE"
    fi
    
    # Dev Container labels (for VS Code integration)
    args+=("--label" "devcontainer.local_folder=$workdir")
    args+=("--label" "com.microsoft.devcontainers.workspaceFolder=/workspace")
    args+=("--label" "devcontainer.config_file=$workdir/.devcontainer/devcontainer.json")
    
    # User mapping
    if [[ "${MLENV_RUN_AS_USER:-true}" == "true" ]]; then
        local user_name="${USER:-mlenv-user}"
        local user_uid="$(id -u)"
        local user_gid="$(id -g)"
        local user_home="/home/${user_name}"
        
        args+=("-e" "MLENV_USER=${user_name}")
        args+=("-e" "MLENV_UID=${user_uid}")
        args+=("-e" "MLENV_GID=${user_gid}")
        args+=("-e" "MLENV_HOME=${user_home}")
        
        vlog "Will create user: ${user_uid}:${user_gid} (${user_name})"
        
        # Mount init script if exists
        local init_script="${MLENV_LOG_DIR}/init.sh"
        if [[ -f "$init_script" ]]; then
            args+=("-v" "${init_script}:/mlenv-init.sh:ro")
            args+=("--entrypoint" "/bin/bash")
        fi
    fi
    
    # Volume mount
    args+=("-v" "$workdir:/workspace")
    args+=("-w" "/workspace")
    
    # Image
    args+=("$image")
    
    # Command
    if [[ "${MLENV_RUN_AS_USER:-true}" == "true" && -f "${MLENV_LOG_DIR}/init.sh" ]]; then
        args+=("-c" "/mlenv-init.sh")
    else
        args+=("sleep" "infinity")
    fi
    
    printf '%s\n' "${args[@]}"
}

# Create init script for user setup
container_create_init_script() {
    local log_dir="$1"
    local init_script="${log_dir}/init.sh"
    
    cat > "$init_script" <<'INIT_SCRIPT'
#!/bin/bash
# MLEnv container initialization script

# Create group if doesn't exist
if ! getent group "${MLENV_GID}" >/dev/null 2>&1; then
    groupadd -g "${MLENV_GID}" "${MLENV_USER}" 2>/dev/null || true
fi

# Create user if doesn't exist
if ! id "${MLENV_UID}" >/dev/null 2>&1; then
    useradd -u "${MLENV_UID}" -g "${MLENV_GID}" -d "${MLENV_HOME}" -s /bin/bash "${MLENV_USER}" 2>/dev/null || true
fi

# Ensure home directory exists and has correct ownership
mkdir -p "${MLENV_HOME}" 2>/dev/null || true
chown "${MLENV_UID}:${MLENV_GID}" "${MLENV_HOME}" 2>/dev/null || true

# Keep container running
exec sleep infinity
INIT_SCRIPT
    
    chmod +x "$init_script"
    vlog "Created init script: $init_script"
}

# Get forwarded ports for container
container_get_forwarded_ports() {
    local container_name="$1"
    
    # Will be implemented via adapter
    # This is a placeholder for the interface
    true
}

# Find suitable Jupyter port from forwarded ports
container_find_jupyter_port() {
    local container_name="$1"
    local forwarded_ports
    
    forwarded_ports=$(container_get_forwarded_ports "$container_name")
    
    if [[ -z "$forwarded_ports" ]]; then
        return 1
    fi
    
    # Check for 8888 first
    if echo "$forwarded_ports" | grep -q ":8888$"; then
        echo "8888"
        return 0
    fi
    
    # Check for 8889-8899
    for port in {8889..8899}; do
        if echo "$forwarded_ports" | grep -q ":${port}$"; then
            echo "$port"
            return 0
        fi
    done
    
    # Return first forwarded port in the range
    local first_port
    first_port=$(echo "$forwarded_ports" | grep -E ":[0-9]+$" | head -1 | cut -d: -f2)
    if [[ -n "$first_port" ]]; then
        echo "$first_port"
        return 0
    fi
    
    return 1
}

# These functions will be implemented by adapters (interface methods)
container_exists() {
    local container_name="$1"
    die "container_exists not implemented - adapter not loaded"
}

container_is_running() {
    local container_name="$1"
    die "container_is_running not implemented - adapter not loaded"
}
