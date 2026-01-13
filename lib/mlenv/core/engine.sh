#!/usr/bin/env bash
# MLEnv Core Engine
# Version: 2.0.0
# Main initialization and orchestration

# Set library path if not set
export MLENV_LIB="${MLENV_LIB:-/usr/local/lib/mlenv}"

# Source all dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/utils/validation.sh"

source "${MLENV_LIB}/config/parser.sh"
source "${MLENV_LIB}/config/defaults.sh"
source "${MLENV_LIB}/config/validator.sh"

source "${MLENV_LIB}/core/container.sh"
source "${MLENV_LIB}/core/image.sh"
source "${MLENV_LIB}/core/auth.sh"
source "${MLENV_LIB}/core/devcontainer.sh"

source "${MLENV_LIB}/ports/container-port.sh"
source "${MLENV_LIB}/ports/image-port.sh"
source "${MLENV_LIB}/ports/auth-port.sh"

# Global state
export MLENV_ACTIVE_CONTAINER_ADAPTER=""
export MLENV_ACTIVE_REGISTRY_ADAPTER=""
export MLENV_INITIALIZED=false

# Initialize MLEnv engine
engine_init() {
    vlog "Initializing MLEnv Engine v2.0.0..."
    
    # Set defaults
    config_set_defaults
    
    # Load configuration
    config_init
    
    # Validate configuration
    config_validate_all
    config_sanitize_all
    
    # Apply configuration to environment
    engine_apply_config
    
    # Initialize adapters
    engine_init_adapters
    
    MLENV_INITIALIZED=true
    vlog "MLEnv Engine initialized successfully"
}

# Apply configuration to environment variables
engine_apply_config() {
    # Apply logging settings
    MLENV_LOG_LEVEL=$(config_get "core.log_level" "info")
    set_log_level "$MLENV_LOG_LEVEL"
    
    # Apply container settings
    export MLENV_DEFAULT_IMAGE=$(config_get "container.default_image" "nvcr.io/nvidia/pytorch:25.12-py3")
    export MLENV_RESTART_POLICY=$(config_get "container.restart_policy" "unless-stopped")
    export MLENV_SHM_SIZE=$(config_get "container.shm_size" "16g")
    export MLENV_RUN_AS_USER=$(config_get "container.run_as_user" "true")
    
    # Apply GPU settings
    export MLENV_GPU_DEVICES=$(config_get "gpu.default_devices" "all")
    
    # Apply network settings
    export MLENV_PORTS=$(config_get "network.default_ports" "")
    
    # Apply resource settings
    export MLENV_MEMORY_LIMIT=$(config_get "resources.default_memory_limit" "")
    export MLENV_CPU_LIMIT=$(config_get "resources.default_cpu_limit" "")
    
    # Apply registry settings
    export MLENV_NGC_REGISTRY=$(config_get "registry.ngc_url" "nvcr.io")
    
    vlog "Configuration applied to environment"
}

# Initialize adapters
engine_init_adapters() {
    local container_adapter=$(config_get "container.adapter" "docker")
    local registry_adapter=$(config_get "registry.default" "ngc")
    
    # Load container adapter
    engine_load_container_adapter "$container_adapter"
    
    # Load registry adapter
    engine_load_registry_adapter "$registry_adapter"
}

# Load container adapter
engine_load_container_adapter() {
    local adapter="$1"
    local adapter_path="${MLENV_LIB}/adapters/container/${adapter}.sh"
    
    if [[ ! -f "$adapter_path" ]]; then
        die "Container adapter not found: $adapter"
    fi
    
    vlog "Loading container adapter: $adapter"
    source "$adapter_path"
    
    # Validate adapter implements interface
    if ! container_port_validate_adapter "$adapter"; then
        die "Container adapter validation failed: $adapter"
    fi
    
    # Initialize adapter
    if declare -f "${adapter}_adapter_init" >/dev/null 2>&1; then
        "${adapter}_adapter_init"
    fi
    
    export MLENV_ACTIVE_CONTAINER_ADAPTER="$adapter"
    success "Container adapter loaded: $adapter"
}

# Load registry adapter
engine_load_registry_adapter() {
    local adapter="$1"
    local adapter_path="${MLENV_LIB}/adapters/registry/${adapter}.sh"
    
    if [[ ! -f "$adapter_path" ]]; then
        warn "Registry adapter not found: $adapter (skipping)"
        return 0
    fi
    
    vlog "Loading registry adapter: $adapter"
    source "$adapter_path"
    
    # Validate adapter implements interface
    if ! auth_port_validate_adapter "$adapter"; then
        warn "Registry adapter validation failed: $adapter"
        return 1
    fi
    
    # Initialize adapter
    if declare -f "${adapter}_adapter_init" >/dev/null 2>&1; then
        "${adapter}_adapter_init"
    fi
    
    export MLENV_ACTIVE_REGISTRY_ADAPTER="$adapter"
    success "Registry adapter loaded: $adapter"
}

# Check if engine is initialized
engine_require_init() {
    if [[ "$MLENV_INITIALIZED" != "true" ]]; then
        die "MLEnv engine not initialized. Call engine_init first."
    fi
}

# Get engine version
engine_get_version() {
    echo "2.0.0"
}

# Get engine info
engine_get_info() {
    echo "MLEnv Engine v$(engine_get_version)"
    echo "Container Adapter: ${MLENV_ACTIVE_CONTAINER_ADAPTER:-none}"
    echo "Registry Adapter: ${MLENV_ACTIVE_REGISTRY_ADAPTER:-none}"
    echo "Log Level: ${MLENV_LOG_LEVEL:-info}"
}
