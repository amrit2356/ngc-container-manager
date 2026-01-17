#!/usr/bin/env bash
# MLEnv Locking Utility
# Version: 2.1.0
# Provides file-based locking for concurrent operations

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# Lock directory and default timeout
MLENV_LOCK_DIR="${MLENV_LOCK_DIR:-/var/lock/mlenv}"
MLENV_LOCK_TIMEOUT="${MLENV_LOCK_TIMEOUT:-30}"

# Initialize lock directory
lock_init() {
    if [[ ! -d "$MLENV_LOCK_DIR" ]]; then
        mkdir -p "$MLENV_LOCK_DIR" 2>/dev/null || {
            # Fallback to user directory if system lock dir not writable
            MLENV_LOCK_DIR="${HOME}/.mlenv/locks"
            mkdir -p "$MLENV_LOCK_DIR" || {
                error "Failed to create lock directory"
                return 1
            }
        }
    fi
    vlog "Lock directory: $MLENV_LOCK_DIR"
}

# Acquire lock with timeout
# Arguments:
#   $1: lock name (e.g., "database", "container-create")
#   $2: timeout in seconds (optional, defaults to MLENV_LOCK_TIMEOUT)
# Returns: 0 on success, 1 on timeout
lock_acquire() {
    local lock_name="$1"
    local timeout="${2:-$MLENV_LOCK_TIMEOUT}"
    local lockfile="${MLENV_LOCK_DIR}/${lock_name}.lock"
    local lock_fd=200
    
    # Ensure lock directory exists
    lock_init || return 1
    
    vlog "Acquiring lock: $lock_name (timeout: ${timeout}s)"
    
    # Try to acquire lock with timeout
    # FD 200 is used consistently for locks
    exec 200>"$lockfile" || {
        error "Failed to open lock file: $lockfile"
        return 1
    }
    
    if flock -x -w "$timeout" 200; then
        vlog "Lock acquired: $lock_name"
        # Store PID for debugging
        echo $$ >&200
        return 0
    else
        error "Lock timeout after ${timeout}s: $lock_name"
        exec 200>&-  # Close FD
        return 1
    fi
}

# Release lock
# Arguments:
#   $1: lock name
# Returns: 0 on success
lock_release() {
    local lock_name="$1"
    
    vlog "Releasing lock: $lock_name"
    
    # Close FD 200 to release lock
    exec 200>&- 2>/dev/null || true
    
    return 0
}

# Execute function with lock
# Arguments:
#   $1: lock name
#   $2: timeout (optional)
#   $@: command to execute
# Returns: exit code of command
lock_execute() {
    local lock_name="$1"
    local timeout="$2"
    shift 2
    local cmd=("$@")
    
    # Validate arguments
    if [[ -z "$lock_name" ]]; then
        error "lock_execute: lock name required"
        return 1
    fi
    
    if [[ ${#cmd[@]} -eq 0 ]]; then
        error "lock_execute: command required"
        return 1
    fi
    
    # Acquire lock
    if ! lock_acquire "$lock_name" "$timeout"; then
        return 1
    fi
    
    # Execute command
    local exit_code=0
    "${cmd[@]}" || exit_code=$?
    
    # Release lock
    lock_release "$lock_name"
    
    return $exit_code
}

# Check if lock is held
# Arguments:
#   $1: lock name
# Returns: 0 if locked, 1 if free
lock_is_held() {
    local lock_name="$1"
    local lockfile="${MLENV_LOCK_DIR}/${lock_name}.lock"
    
    if [[ ! -f "$lockfile" ]]; then
        return 1
    fi
    
    # Try to acquire non-blocking
    if flock -n -x "$lockfile" true 2>/dev/null; then
        return 1  # Lock is free
    else
        return 0  # Lock is held
    fi
}

# Get lock holder PID
# Arguments:
#   $1: lock name
# Returns: PID if locked, empty if free
lock_get_holder() {
    local lock_name="$1"
    local lockfile="${MLENV_LOCK_DIR}/${lock_name}.lock"
    
    if [[ -f "$lockfile" ]] && lock_is_held "$lock_name"; then
        cat "$lockfile" 2>/dev/null || echo ""
    fi
}

# Clean stale locks (for maintenance)
# Removes locks where holder PID no longer exists
lock_clean_stale() {
    local cleaned=0
    
    if [[ ! -d "$MLENV_LOCK_DIR" ]]; then
        return 0
    fi
    
    for lockfile in "$MLENV_LOCK_DIR"/*.lock; do
        if [[ ! -f "$lockfile" ]]; then
            continue
        fi
        
        local lock_name=$(basename "$lockfile" .lock)
        local holder_pid=$(lock_get_holder "$lock_name")
        
        if [[ -n "$holder_pid" ]] && ! ps -p "$holder_pid" >/dev/null 2>&1; then
            vlog "Cleaning stale lock: $lock_name (PID $holder_pid)"
            rm -f "$lockfile"
            ((cleaned++))
        fi
    done
    
    if [[ $cleaned -gt 0 ]]; then
        info "Cleaned $cleaned stale lock(s)"
    fi
}

vlog "Locking utility loaded"
