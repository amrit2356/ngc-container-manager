#!/usr/bin/env bash
# MLEnv Input Sanitization
# Version: 2.1.0
# Provides security functions to prevent command injection and validate inputs

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# Sanitize command for safe execution
# Removes dangerous shell metacharacters
# Arguments:
#   $1: Command string to sanitize
# Returns: Sanitized command string
sanitize_command() {
    local cmd="$1"
    
    # Remove dangerous sequences
    # ; & | ` $ ( ) { } are shell metacharacters
    cmd=$(echo "$cmd" | sed 's/[;&|`$(){}]//g')
    
    # Remove control characters
    cmd=$(echo "$cmd" | tr -d '\000-\037')
    
    # Remove newlines and carriage returns
    cmd=$(echo "$cmd" | tr -d '\n\r')
    
    echo "$cmd"
}

# Validate command is safe to execute
# Checks for shell metacharacters and dangerous patterns
# Arguments:
#   $1: Command string to validate
# Returns: 0 if safe, 1 if dangerous
validate_safe_command() {
    local cmd="$1"
    
    # Check for shell metacharacters (injection attempts)
    # Using grep for more reliable detection
    if echo "$cmd" | grep -qE '[;|&`$()<>{}]'; then
        vlog "Unsafe command detected: contains shell metacharacters"
        return 1
    fi
    
    # Check for path traversal
    if [[ "$cmd" =~ \.\./|\.\.\\  ]]; then
        vlog "Unsafe command detected: path traversal attempt"
        return 1
    fi
    
    # Check for suspicious patterns
    if [[ "$cmd" =~ rm[[:space:]]+-rf|sudo|su[[:space:]]|chmod[[:space:]]777 ]]; then
        vlog "Unsafe command detected: dangerous pattern"
        return 1
    fi
    
    return 0
}

# Execute command safely in container using array
# This is the preferred method for safe execution
# Arguments:
#   $1: container_name
#   $2: user_args (e.g., "--user 1000:1000" or empty)
#   $@: command array (e.g., bash -c "command")
safe_container_exec() {
    local container_name="$1"
    local user_args="$2"
    shift 2
    local cmd_array=("$@")
    
    # Validate container name first
    if ! validate_container_name "$container_name"; then
        error "Invalid container name: $container_name"
        return 1
    fi
    
    # Execute using array (prevents injection)
    vlog "Executing safe command in container: $container_name"
    docker exec $user_args "$container_name" "${cmd_array[@]}"
}

# Validate container name format
# Docker container names must match: [a-zA-Z0-9][a-zA-Z0-9_.-]*
# Arguments:
#   $1: Container name to validate
# Returns: 0 if valid, 1 if invalid
validate_container_name() {
    local name="$1"
    
    # Check if empty
    if [[ -z "$name" ]]; then
        vlog "Container name is empty"
        return 1
    fi
    
    # Docker container name rules
    if ! [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        vlog "Invalid container name format: $name"
        return 1
    fi
    
    # Length check (Docker limit is 64 characters)
    if [[ ${#name} -gt 64 ]]; then
        vlog "Container name too long: ${#name} > 64"
        return 1
    fi
    
    return 0
}

# Validate image name format
# Docker image format: [registry/]repository[:tag]
# Arguments:
#   $1: Image name to validate
# Returns: 0 if valid, 1 if invalid
validate_image_name() {
    local image="$1"
    
    # Check if empty
    if [[ -z "$image" ]]; then
        vlog "Image name is empty"
        return 1
    fi
    
    # Docker image name format with registry, repo, and optional tag
    # Examples: 
    #   - pytorch:latest
    #   - nvcr.io/nvidia/pytorch:25.12-py3
    #   - registry.io/org/repo:tag
    if ! [[ "$image" =~ ^[a-zA-Z0-9./_-]+(:[a-zA-Z0-9._-]+)?$ ]]; then
        vlog "Invalid image name format: $image"
        return 1
    fi
    
    # Check for injection attempts (shell metacharacters)
    if echo "$image" | grep -qE '[;|&`$()<>{}]'; then
        vlog "Image name contains dangerous characters: $image"
        return 1
    fi
    
    return 0
}

# Validate port number
# Arguments:
#   $1: Port number to validate
# Returns: 0 if valid, 1 if invalid
validate_port_number() {
    local port="$1"
    
    # Must be a number
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        vlog "Port is not a number: $port"
        return 1
    fi
    
    # Valid port range: 1-65535
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        vlog "Port out of range: $port (valid: 1-65535)"
        return 1
    fi
    
    return 0
}

# Validate file path (prevent path traversal)
# Arguments:
#   $1: File path to validate
#   $2: Base directory (optional, defaults to current directory)
# Returns: 0 if safe, 1 if dangerous
validate_safe_path() {
    local path="$1"
    local base_dir="${2:-$(pwd)}"
    
    # Check if path is empty
    if [[ -z "$path" ]]; then
        vlog "Path is empty"
        return 1
    fi
    
    # Resolve to absolute path (without following symlinks for security)
    local abs_path
    abs_path=$(realpath -m "$path" 2>/dev/null) || {
        vlog "Failed to resolve path: $path"
        return 1
    }
    
    # Resolve base directory
    local abs_base
    abs_base=$(realpath -m "$base_dir" 2>/dev/null) || {
        vlog "Failed to resolve base directory: $base_dir"
        return 1
    }
    
    # Check if path is within base directory (prevent path traversal)
    if [[ ! "$abs_path" =~ ^"$abs_base" ]]; then
        # Allow /tmp and /var/tmp for temporary files
        if [[ ! "$abs_path" =~ ^/tmp ]] && [[ ! "$abs_path" =~ ^/var/tmp ]]; then
            vlog "Path outside allowed directories: $path"
            return 1
        fi
    fi
    
    return 0
}

# Sanitize string for general use
# Removes quotes, semicolons, and other dangerous characters
# Arguments:
#   $1: String to sanitize
# Returns: Sanitized string
sanitize_string() {
    local str="$1"
    
    # Remove dangerous characters
    str=$(echo "$str" | tr -d '\n\r')
    str=$(echo "$str" | sed "s/[';\"&|<>]//g")
    
    echo "$str"
}

# Validate project/directory name
# Arguments:
#   $1: Project name to validate
# Returns: 0 if valid, 1 if invalid
validate_project_name() {
    local name="$1"
    
    # Check if empty
    if [[ -z "$name" ]]; then
        vlog "Project name is empty"
        return 1
    fi
    
    # Allow alphanumeric, underscore, dash, dot
    # Must not start with dash or dot
    if ! [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        vlog "Invalid project name format: $name"
        return 1
    fi
    
    # Length check (reasonable limit)
    if [[ ${#name} -gt 255 ]]; then
        vlog "Project name too long: ${#name} > 255"
        return 1
    fi
    
    # Disallow dangerous names
    if [[ "$name" =~ ^(\.\.?|/)$ ]]; then
        vlog "Dangerous project name: $name"
        return 1
    fi
    
    return 0
}

vlog "Sanitization module loaded"
