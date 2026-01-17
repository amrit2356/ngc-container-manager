#!/usr/bin/env bash
# MLEnv Input Validation
# Version: 2.0.0

# Validate port format (e.g., "8888:8888" or "8888:8888,6006:6006")
validate_ports() {
    local ports="$1"
    
    if [[ -z "$ports" ]]; then
        return 0
    fi
    
    if ! [[ "$ports" =~ ^[0-9:]+(,[0-9:]+)*$ ]]; then
        return 1
    fi
    
    # Validate each port mapping
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    for port_mapping in "${PORT_ARRAY[@]}"; do
        if ! [[ "$port_mapping" =~ ^[0-9]+:[0-9]+$ ]]; then
            return 1
        fi
        
        # Extract and validate port numbers
        IFS=':' read -r host_port container_port <<< "$port_mapping"
        
        if (( host_port < 1 || host_port > 65535 )); then
            return 1
        fi
        
        if (( container_port < 1 || container_port > 65535 )); then
            return 1
        fi
    done
    
    return 0
}

# Validate GPU devices format
validate_gpu_devices() {
    local devices="$1"
    
    if [[ -z "$devices" || "$devices" == "all" ]]; then
        return 0
    fi
    
    # Should be comma-separated numbers
    if ! [[ "$devices" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate container name
validate_container_name() {
    local name="$1"
    
    # Docker container name requirements
    if ! [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate image name
validate_image_name() {
    local image="$1"
    
    if [[ -z "$image" ]]; then
        return 1
    fi
    
    # Basic image name validation (registry/org/image:tag)
    if ! [[ "$image" =~ ^[a-z0-9./-]+(:[ a-zA-Z0-9._-]+)?$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate memory limit format
validate_memory_limit() {
    local limit="$1"
    
    if [[ -z "$limit" ]]; then
        return 0
    fi
    
    # Should be number followed by unit (k, m, g)
    if ! [[ "$limit" =~ ^[0-9]+[kmgKMG]?$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate CPU limit format
validate_cpu_limit() {
    local limit="$1"
    
    if [[ -z "$limit" ]]; then
        return 0
    fi
    
    # Should be a number (can be decimal)
    if ! [[ "$limit" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate path is absolute
validate_absolute_path() {
    local path="$1"
    
    if ! [[ "$path" =~ ^/ ]]; then
        return 1
    fi
    
    return 0
}

# Validate file is readable
validate_readable_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        return 1
    fi
    
    return 0
}

# Sanitize string for shell use
sanitize_string() {
    local str="$1"
    # Remove dangerous characters
    echo "$str" | tr -d '\n\r' | sed "s/[';\"&|<>]//g"
}

# Validate boolean value
validate_boolean() {
    local value="$1"
    
    case "$value" in
        true|false|yes|no|1|0)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Normalize boolean
normalize_boolean() {
    local value="$1"
    
    case "$value" in
        true|yes|1)
            echo "true"
            ;;
        false|no|0)
            echo "false"
            ;;
        *)
            echo "false"
            ;;
    esac
}

# Validate Docker is available
validate_docker() {
    if ! command -v docker &>/dev/null; then
        error "Docker is not installed or not in PATH"
        info "Install Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    if ! docker info &>/dev/null; then
        error "Docker daemon is not running"
        info "Start Docker and try again"
        return 1
    fi
    
    return 0
}

# Validate workspace directory
validate_workspace() {
    local workdir="$1"
    
    if [[ ! -d "$workdir" ]]; then
        error "Workspace directory does not exist: $workdir"
        return 1
    fi
    
    if [[ ! -w "$workdir" ]]; then
        error "Workspace directory is not writable: $workdir"
        return 1
    fi
    
    return 0
}

# Validate requirements file
validate_requirements_file() {
    local file="$1"
    
    if [[ -z "$file" ]]; then
        return 0
    fi
    
    if [[ ! -f "$file" ]]; then
        error "Requirements file not found: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        error "Requirements file is not readable: $file"
        return 1
    fi
    
    # Basic syntax check
    if grep -q '[^a-zA-Z0-9_=<>!.,-]' "$file" 2>/dev/null; then
        warn "Requirements file may contain invalid characters"
    fi
    
    return 0
}
