#!/usr/bin/env bash
# MLEnv Retry Utility
# Version: 2.1.0
# Provides retry logic with exponential backoff for transient failures

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"

# Retry a command with exponential backoff
# Arguments:
#   $1: max attempts (default: 3)
#   $2: initial delay in seconds (default: 2)
#   $@: command to execute
# Returns: exit code of command (0 on success, 1 on all attempts failed)
# 
# Example:
#   retry_with_backoff 3 2 docker pull myimage:latest
#   retry_with_backoff 5 1 curl -f https://api.example.com
retry_with_backoff() {
    local max_attempts="${1:-3}"
    local initial_delay="${2:-2}"
    shift 2
    
    local attempt=1
    local delay="$initial_delay"
    local exit_code=0
    
    if [[ ${#@} -eq 0 ]]; then
        error "retry_with_backoff: command required"
        return 1
    fi
    
    vlog "Retry: attempting command (max $max_attempts attempts)"
    
    while (( attempt <= max_attempts )); do
        vlog "Retry: attempt $attempt/$max_attempts"
        
        # Execute command
        if "$@"; then
            if [[ $attempt -gt 1 ]]; then
                success "Command succeeded on attempt $attempt"
            fi
            return 0
        fi
        
        exit_code=$?
        
        # Check if we should retry
        if (( attempt < max_attempts )); then
            warn "Attempt $attempt failed (exit code: $exit_code), retrying in ${delay}s..."
            sleep "$delay"
            
            # Exponential backoff: delay *= 2
            delay=$((delay * 2))
        else
            error "All $max_attempts attempts failed"
        fi
        
        ((attempt++))
    done
    
    return $exit_code
}

# Retry with linear backoff (constant delay)
# Arguments:
#   $1: max attempts
#   $2: delay in seconds
#   $@: command to execute
retry_with_linear_backoff() {
    local max_attempts="${1:-3}"
    local delay="${2:-2}"
    shift 2
    
    local attempt=1
    local exit_code=0
    
    if [[ ${#@} -eq 0 ]]; then
        error "retry_with_linear_backoff: command required"
        return 1
    fi
    
    while (( attempt <= max_attempts )); do
        vlog "Retry: attempt $attempt/$max_attempts"
        
        if "$@"; then
            if [[ $attempt -gt 1 ]]; then
                success "Command succeeded on attempt $attempt"
            fi
            return 0
        fi
        
        exit_code=$?
        
        if (( attempt < max_attempts )); then
            warn "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    error "All $max_attempts attempts failed"
    return $exit_code
}

# Retry until success or timeout
# Arguments:
#   $1: timeout in seconds
#   $2: check interval in seconds
#   $@: command to execute
# Returns: 0 on success, 1 on timeout
retry_until_timeout() {
    local timeout="${1:-60}"
    local interval="${2:-5}"
    shift 2
    
    local elapsed=0
    local attempt=1
    
    if [[ ${#@} -eq 0 ]]; then
        error "retry_until_timeout: command required"
        return 1
    fi
    
    vlog "Retry: polling until success (timeout: ${timeout}s, interval: ${interval}s)"
    
    while (( elapsed < timeout )); do
        vlog "Retry: attempt $attempt (elapsed: ${elapsed}s)"
        
        if "$@"; then
            success "Command succeeded after ${elapsed}s"
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        ((attempt++))
    done
    
    error "Timeout after ${timeout}s"
    return 1
}

# Retry with custom backoff function
# Arguments:
#   $1: max attempts
#   $2: backoff function name (receives attempt number, returns delay)
#   $@: command to execute
retry_with_custom_backoff() {
    local max_attempts="${1:-3}"
    local backoff_fn="${2:-}"
    shift 2
    
    if [[ -z "$backoff_fn" ]] || ! declare -f "$backoff_fn" >/dev/null 2>&1; then
        error "retry_with_custom_backoff: valid backoff function required"
        return 1
    fi
    
    if [[ ${#@} -eq 0 ]]; then
        error "retry_with_custom_backoff: command required"
        return 1
    fi
    
    local attempt=1
    local exit_code=0
    
    while (( attempt <= max_attempts )); do
        vlog "Retry: attempt $attempt/$max_attempts"
        
        if "$@"; then
            if [[ $attempt -gt 1 ]]; then
                success "Command succeeded on attempt $attempt"
            fi
            return 0
        fi
        
        exit_code=$?
        
        if (( attempt < max_attempts )); then
            local delay=$("$backoff_fn" "$attempt")
            warn "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    error "All $max_attempts attempts failed"
    return $exit_code
}

# Predefined backoff functions

# Fibonacci backoff: 1, 1, 2, 3, 5, 8, 13...
backoff_fibonacci() {
    local n="$1"
    if (( n <= 1 )); then
        echo "1"
    elif (( n == 2 )); then
        echo "1"
    else
        local a=1
        local b=1
        for ((i=3; i<=n; i++)); do
            local temp=$((a + b))
            a=$b
            b=$temp
        done
        echo "$b"
    fi
}

# Jittered exponential backoff (adds randomness to prevent thundering herd)
backoff_jittered_exponential() {
    local attempt="$1"
    local base_delay=$((2 ** attempt))
    local jitter=$((RANDOM % base_delay))
    echo $((base_delay + jitter))
}

vlog "Retry utility loaded"
