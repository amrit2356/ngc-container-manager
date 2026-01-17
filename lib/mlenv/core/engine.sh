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
source "${MLENV_LIB}/config/accessor.sh"
source "${MLENV_LIB}/config/validator.sh"

source "${MLENV_LIB}/core/context.sh"
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
    # Apply logging settings using effective config (respects CLI flags and env vars)
    MLENV_LOG_LEVEL=$(config_get_effective "core.log_level" "info")
    set_log_level "$MLENV_LOG_LEVEL"
    
    # Export all configuration to environment using unified accessor
    config_export_to_env
    
    vlog "Configuration applied to environment"
}

# Initialize adapters
engine_init_adapters() {
    local container_adapter=$(config_get_effective "container.adapter" "docker")
    local registry_adapter=$(config_get_effective "registry.default" "ngc")
    
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
    vlog "Container adapter loaded: $adapter"
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
    vlog "Registry adapter loaded: $adapter"
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
