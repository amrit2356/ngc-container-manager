#!/usr/bin/env bash
# MLEnv Command Helper Functions
# Version: 2.1.0
# Common patterns and helpers for command implementations

# Source dependencies
source "${MLENV_LIB}/core/context.sh"
source "${MLENV_LIB}/utils/validation.sh"
source "${MLENV_LIB}/utils/sanitization.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/core/container.sh"

# Initialize context with validation
# This reduces boilerplate from 8 lines to 1 line in commands
# Arguments:
#   $1: Name of the associative array variable (nameref)
# Returns: 0 on success, 1 on failure
cmd_init_context() {
    local -n ctx_out=$1
    
    mlenv_context_create ctx_out
    
    if ! mlenv_context_validate ctx_out; then
        error_with_help "Failed to initialize context" "invalid_argument"
        return 1
    fi
    
    return 0
}

# Require container to be running
# Arguments:
#   $1: Container name
# Returns: 0 if running, 1 if not
cmd_require_running() {
    local container_name="$1"
    
    if [[ -z "$container_name" ]]; then
        error_with_help "Container name not specified" "invalid_argument"
        return 1
    fi
    
    if ! container_is_running "$container_name"; then
        error_with_help "Container not running: $container_name" "container_not_running"
        return 1
    fi
    
    return 0
}

# Require container to exist (running or stopped)
# Arguments:
#   $1: Container name
# Returns: 0 if exists, 1 if not
cmd_require_exists() {
    local container_name="$1"
    
    if [[ -z "$container_name" ]]; then
        error_with_help "Container name not specified" "invalid_argument"
        return 1
    fi
    
    if ! container_exists "$container_name"; then
        error_with_help "Container does not exist: $container_name" "container_error"
        info "Create container with: mlenv up"
        return 1
    fi
    
    return 0
}

# Require Docker to be installed and running
# Returns: 0 if available, 1 if not
cmd_require_docker() {
    if ! validate_docker; then
        error_with_help "Docker validation failed" "docker_not_found"
        return 1
    fi
    
    return 0
}

# Require NVIDIA runtime to be available
# Returns: 0 if available, 1 if not
cmd_require_nvidia() {
    if ! command -v nvidia-smi &>/dev/null; then
        error_with_help "NVIDIA GPU driver not found" "nvidia_driver_not_found"
        return 1
    fi
    
    if ! docker info 2>/dev/null | grep -q "Runtimes:.*nvidia"; then
        error_with_help "NVIDIA Container Toolkit not detected" "nvidia_toolkit_not_found"
        return 1
    fi
    
    return 0
}

# Require both Docker and NVIDIA (common prerequisite)
# Returns: 0 if both available, 1 if not
cmd_require_container_env() {
    cmd_require_docker || return 1
    cmd_require_nvidia || return 1
    return 0
}

# Find an available port starting from a given port
# Arguments:
#   $1: Starting port (default: 8888)
#   $2: Max attempts (default: 100)
# Returns: Available port number or empty string
# Outputs: Port number to stdout
cmd_find_available_port() {
    local start_port="${1:-8888}"
    local max_attempts="${2:-100}"
    
    # Validate start port
    if ! validate_port_number "$start_port"; then
        error "Invalid start port: $start_port"
        return 1
    fi
    
    for ((i=0; i<max_attempts; i++)); do
        local port=$((start_port + i))
        
        # Check if port is in valid range
        if [[ $port -gt 65535 ]]; then
            break
        fi
        
        # Check if port is available (using netstat or ss)
        if ! (netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null) | grep -q ":${port} "; then
            echo "$port"
            return 0
        fi
    done
    
    # No available port found
    return 1
}

# Auto-detect requirements.txt in project
# Arguments:
#   $1: Workdir path
#   $2: Current requirements path (may be empty)
# Returns: Requirements path (existing or auto-detected) or empty
# Outputs: Path to stdout
cmd_auto_detect_requirements() {
    local workdir="$1"
    local current_req="${2:-}"
    
    # If already specified, use that
    if [[ -n "$current_req" ]]; then
        echo "$current_req"
        return 0
    fi
    
    # Try to auto-detect
    local req_file="${workdir}/requirements.txt"
    if [[ -f "$req_file" ]]; then
        info "Auto-detected requirements.txt"
        echo "$req_file"
        return 0
    fi
    
    # No requirements found
    return 1
}

# Validate and sanitize container name from context
# Arguments:
#   $1: Container name
# Returns: 0 if valid, 1 if invalid
cmd_validate_container_name() {
    local name="$1"
    
    if ! validate_container_name "$name"; then
        error_with_help "Invalid container name: $name" "invalid_argument"
        info "Container names must start with alphanumeric and contain only [a-zA-Z0-9_.-]"
        return 1
    fi
    
    return 0
}

# Validate and sanitize image name
# Arguments:
#   $1: Image name
# Returns: 0 if valid, 1 if invalid
cmd_validate_image_name() {
    local image="$1"
    
    if ! validate_image_name "$image"; then
        error_with_help "Invalid image name: $image" "invalid_argument"
        info "Image format: [registry/]repository[:tag]"
        return 1
    fi
    
    return 0
}

# Get host port for a container port mapping
# Arguments:
#   $1: Container name
#   $2: Container port
# Returns: Host port number or empty
# Outputs: Port number to stdout
cmd_get_host_port() {
    local container_name="$1"
    local container_port="$2"
    
    # Validate inputs
    cmd_validate_container_name "$container_name" || return 1
    validate_port_number "$container_port" || return 1
    
    # Query Docker for port mapping
    local host_port
    host_port=$(docker port "$container_name" "${container_port}/tcp" 2>/dev/null | cut -d: -f2)
    
    if [[ -n "$host_port" ]]; then
        echo "$host_port"
        return 0
    fi
    
    return 1
}

# Check if a port is already in use
# Arguments:
#   $1: Port number
# Returns: 0 if in use, 1 if available
is_port_in_use() {
    local port="$1"
    
    validate_port_number "$port" || return 1
    
    # Check using netstat or ss
    if (netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null) | grep -q ":${port} "; then
        return 0  # Port is in use
    fi
    
    return 1  # Port is available
}

# Validate workspace directory
# Arguments:
#   $1: Workspace path
# Returns: 0 if valid, 1 if invalid
cmd_validate_workspace() {
    local workdir="$1"
    
    if ! validate_workspace "$workdir"; then
        error_with_help "Workspace validation failed: $workdir" "file_not_found"
        return 1
    fi
    
    return 0
}

# Check if a file exists and is readable
# Arguments:
#   $1: File path
#   $2: File description (for error messages)
# Returns: 0 if valid, 1 if not
cmd_require_file() {
    local file_path="$1"
    local description="${2:-File}"
    
    if [[ ! -f "$file_path" ]]; then
        error_with_help "$description not found: $file_path" "file_not_found"
        return 1
    fi
    
    if [[ ! -r "$file_path" ]]; then
        error_with_help "$description not readable: $file_path" "permission_denied"
        return 1
    fi
    
    return 0
}

# Ensure directory exists and is writable
# Arguments:
#   $1: Directory path
#   $2: Directory description (for error messages)
# Returns: 0 if valid/created, 1 if not
cmd_ensure_directory() {
    local dir_path="$1"
    local description="${2:-Directory}"
    
    # Try to create if doesn't exist
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path" 2>/dev/null || {
            error_with_help "Failed to create $description: $dir_path" "permission_denied"
            return 1
        }
    fi
    
    # Check writable
    if [[ ! -w "$dir_path" ]]; then
        error_with_help "$description not writable: $dir_path" "permission_denied"
        return 1
    fi
    
    return 0
}

vlog "Command helper functions loaded"
