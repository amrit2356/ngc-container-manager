#!/usr/bin/env bash
# MLEnv Logging Utilities
# Version: 2.0.0

# Global log configuration
MLENV_LOG_LEVEL="${MLENV_LOG_LEVEL:-info}"
MLENV_LOG_FILE="${MLENV_LOG_FILE:-}"
MLENV_VERBOSE="${MLENV_VERBOSE:-false}"

# Log levels
declare -A LOG_LEVELS=(
    [debug]=0
    [info]=1
    [warn]=2
    [error]=3
)

# Get numeric log level
get_log_level() {
    echo "${LOG_LEVELS[${1:-info}]}"
}

# Check if message should be logged
should_log() {
    local level="$1"
    local current_level=$(get_log_level "$MLENV_LOG_LEVEL")
    local message_level=$(get_log_level "$level")
    
    [[ $message_level -ge $current_level ]]
}

# Core logging function
_log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local formatted="[$timestamp] [$level] $message"
    
    # Log to file if configured
    if [[ -n "$MLENV_LOG_FILE" ]]; then
        echo "$formatted" >> "$MLENV_LOG_FILE"
    fi
    
    # Return formatted message
    echo "$formatted"
}

# Public logging functions
log() {
    local message="$1"
    if should_log "info"; then
        echo "$message"
        [[ -n "$MLENV_LOG_FILE" ]] && echo "$message" >> "$MLENV_LOG_FILE" || true
    fi
}

vlog() {
    local message="$1"
    local formatted="$(_log "DEBUG" "$message")"
    
    if [[ "$MLENV_VERBOSE" = true ]] && should_log "debug"; then
        echo "$formatted" >&2
    elif [[ -n "$MLENV_LOG_FILE" ]]; then
        echo "$formatted" >> "$MLENV_LOG_FILE" || true
    fi
}

info() {
    local message="$1"
    if should_log "info"; then
        echo "ℹ $message"
        [[ -n "$MLENV_LOG_FILE" ]] && echo "ℹ $message" >> "$MLENV_LOG_FILE" || true
    fi
}

success() {
    local message="$1"
    if should_log "info"; then
        echo "✔ $message"
        [[ -n "$MLENV_LOG_FILE" ]] && echo "✔ $message" >> "$MLENV_LOG_FILE" || true
    fi
}

warn() {
    local message="$1"
    if should_log "warn"; then
        echo "⚠ $message" >&2
        [[ -n "$MLENV_LOG_FILE" ]] && echo "⚠ $message" >> "$MLENV_LOG_FILE" || true
    fi
}

error() {
    local message="$1"
    _log "ERROR" "$message"
    echo "✖ $message" >&2
}

# Set log level
set_log_level() {
    local level="$1"
    if [[ -n "${LOG_LEVELS[$level]}" ]]; then
        MLENV_LOG_LEVEL="$level"
        vlog "Log level set to: $level"
    else
        warn "Invalid log level: $level (using info)"
        MLENV_LOG_LEVEL="info"
    fi
}

# Enable verbose mode
set_verbose() {
    local enabled="${1:-true}"
    MLENV_VERBOSE="$enabled"
    vlog "Verbose mode: $enabled"
}

# Set log file
set_log_file() {
    local file="$1"
    local dir="$(dirname "$file")"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            warn "Cannot create log directory: $dir"
            return 1
        }
    fi
    
    MLENV_LOG_FILE="$file"
    vlog "Log file set to: $file"
}
