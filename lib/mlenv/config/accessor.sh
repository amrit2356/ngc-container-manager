#!/usr/bin/env bash
# MLEnv Configuration Accessor
# Version: 2.0.0
# Unified config access with clear precedence

# Configuration Precedence (Highest to Lowest):
# 1. Command-line flags (--image, --gpu, etc.)
# 2. Environment variables (MLENV_DEFAULT_IMAGE, MLENV_GPU_DEVICES)
# 3. Project config (.mlenv/config)
# 4. User config (~/.mlenvrc)
# 5. System config (/etc/mlenv/mlenv.conf)
# 6. Built-in defaults (lib/mlenv/config/defaults.sh)

# Get config with full precedence chain
config_get_effective() {
    local key="$1"
    local default="${2:-}"
    
    # Check command-line flag variables first (highest priority)
    case "$key" in
        "container.default_image")
            [[ -n "${IMAGE:-}" ]] && echo "$IMAGE" && return
            ;;
        "gpu.default_devices")
            [[ -n "${GPU_DEVICES:-}" ]] && echo "$GPU_DEVICES" && return
            ;;
        "network.default_ports")
            [[ -n "${PORTS:-}" ]] && echo "$PORTS" && return
            ;;
        "storage.workdir_mount")
            [[ -n "${WORKDIR_MOUNT:-}" ]] && echo "$WORKDIR_MOUNT" && return
            ;;
        "resources.default_memory_limit")
            [[ -n "${MEMORY_LIMIT:-}" ]] && echo "$MEMORY_LIMIT" && return
            ;;
        "resources.default_cpu_limit")
            [[ -n "${CPU_LIMIT:-}" ]] && echo "$CPU_LIMIT" && return
            ;;
        "container.run_as_user")
            [[ -n "${RUN_AS_USER:-}" ]] && echo "$RUN_AS_USER" && return
            ;;
        "requirements.path")
            [[ -n "${REQUIREMENTS_PATH:-}" ]] && echo "$REQUIREMENTS_PATH" && return
            ;;
        "requirements.force_reinstall")
            [[ -n "${FORCE_REQUIREMENTS:-}" ]] && echo "$FORCE_REQUIREMENTS" && return
            ;;
    esac
    
    # Check environment variables (second priority)
    local env_var=$(config_key_to_env "$key")
    if [[ -n "$env_var" ]] && [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
        return
    fi
    
    # Check config array (loaded from files, third-fifth priority)
    if [[ -n "${MLENV_CONFIG[$key]:-}" ]]; then
        echo "${MLENV_CONFIG[$key]}"
        return
    fi
    
    # Return default (lowest priority)
    echo "$default"
}

# Convert config key to env var name
config_key_to_env() {
    local key="$1"
    case "$key" in
        "container.default_image") echo "MLENV_DEFAULT_IMAGE" ;;
        "container.adapter") echo "MLENV_ADAPTER" ;;
        "container.runtime") echo "MLENV_RUNTIME" ;;
        "gpu.default_devices") echo "MLENV_GPU_DEVICES" ;;
        "network.default_ports") echo "MLENV_PORTS" ;;
        "network.jupyter_default_port") echo "MLENV_JUPYTER_PORT" ;;
        "core.log_level") echo "MLENV_LOG_LEVEL" ;;
        "registry.ngc_url") echo "MLENV_NGC_REGISTRY" ;;
        *) echo "" ;;
    esac
}

# List all config sources for a key (for debugging)
config_trace_key() {
    local key="$1"
    
    echo "Configuration trace for: $key"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check command-line flags
    case "$key" in
        "container.default_image")
            [[ -n "${IMAGE:-}" ]] && echo "  [CLI Flag] IMAGE=$IMAGE" || echo "  [CLI Flag] (not set)"
            ;;
        "gpu.default_devices")
            [[ -n "${GPU_DEVICES:-}" ]] && echo "  [CLI Flag] GPU_DEVICES=$GPU_DEVICES" || echo "  [CLI Flag] (not set)"
            ;;
    esac
    
    # Check environment variables
    local env_var=$(config_key_to_env "$key")
    if [[ -n "$env_var" ]]; then
        [[ -n "${!env_var:-}" ]] && echo "  [Env Var] $env_var=${!env_var}" || echo "  [Env Var] $env_var (not set)"
    fi
    
    # Check config array
    [[ -n "${MLENV_CONFIG[$key]:-}" ]] && echo "  [Config] $key=${MLENV_CONFIG[$key]}" || echo "  [Config] $key (not set)"
    
    # Show effective value
    local effective=$(config_get_effective "$key" "(no default)")
    echo "  [Effective] $effective"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Export config values to environment for backward compatibility
config_export_to_env() {
    # Export commonly used values
    export MLENV_DEFAULT_IMAGE=$(config_get_effective "container.default_image" "nvcr.io/nvidia/pytorch:25.12-py3")
    export MLENV_GPU_DEVICES=$(config_get_effective "gpu.default_devices" "all")
    export MLENV_PORTS=$(config_get_effective "network.default_ports" "")
    export MLENV_RESTART_POLICY=$(config_get_effective "container.restart_policy" "unless-stopped")
    export MLENV_SHM_SIZE=$(config_get_effective "container.shm_size" "16g")
    export MLENV_RUN_AS_USER=$(config_get_effective "container.run_as_user" "true")
    export MLENV_NGC_REGISTRY=$(config_get_effective "registry.ngc_url" "nvcr.io")
    
    vlog "Configuration exported to environment variables"
}
