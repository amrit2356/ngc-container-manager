#!/usr/bin/env bash
# MLEnv Context Management
# Version: 2.1.0
# Provides structured context instead of global variables

# Create mlenv context
mlenv_context_create() {
    local -n _ctx_ref=$1
    
    # Get workdir first
    local _wd="${WORKDIR:-$(pwd)}"
    local _pn="$(basename "$_wd")"
    local _wh="$(echo "$_wd" | md5sum | cut -c1-8)"
    
    # Add timestamp and PID for uniqueness if MLENV_UNIQUE_NAMES is enabled
    # This prevents race conditions in concurrent container creation
    local _unique_suffix=""
    if [[ "${MLENV_UNIQUE_NAMES:-false}" == "true" ]]; then
        _unique_suffix="-$(date +%s)-$$"
    fi
    
    local _cn="mlenv-${_pn}-${_wh}${_unique_suffix}"
    local _ld="${_wd}/.mlenv"
    
    # Environment
    _ctx_ref[version]="2.0.0"
    _ctx_ref[workdir]="$_wd"
    _ctx_ref[project_name]="$_pn"
    _ctx_ref[workdir_hash]="$_wh"
    
    # Container
    _ctx_ref[container_name]="$_cn"
    
    # Paths
    _ctx_ref[log_dir]="$_ld"
    _ctx_ref[log_file]="${_ld}/mlenv.log"
    _ctx_ref[requirements_marker]="${_ld}/.requirements_installed"
    
    # Command-line options (populated from global vars for compatibility)
    _ctx_ref[image]="${IMAGE:-}"
    _ctx_ref[requirements_path]="${REQUIREMENTS_PATH:-}"
    _ctx_ref[force_requirements]="${FORCE_REQUIREMENTS:-false}"
    _ctx_ref[verbose]="${VERBOSE:-false}"
    _ctx_ref[ports]="${PORTS:-}"
    _ctx_ref[jupyter_port]="${JUPYTER_PORT:-}"
    _ctx_ref[gpu_devices]="${GPU_DEVICES:-}"
    _ctx_ref[env_file]="${ENV_FILE:-}"
    _ctx_ref[memory_limit]="${MEMORY_LIMIT:-}"
    _ctx_ref[cpu_limit]="${CPU_LIMIT:-}"
    _ctx_ref[run_as_user]="${RUN_AS_USER:-true}"
    _ctx_ref[exec_cmd]="${EXEC_CMD:-}"
    
    vlog "Context created for project: $_pn"
}

# Validate context has required fields
mlenv_context_validate() {
    local -n _ctx_ref=$1
    
    if [[ -z "${_ctx_ref[workdir]}" ]]; then
        error "Context missing workdir"
        return 1
    fi
    
    if [[ -z "${_ctx_ref[container_name]}" ]]; then
        error "Context missing container_name"
        return 1
    fi
    
    if [[ -z "${_ctx_ref[project_name]}" ]]; then
        error "Context missing project_name"
        return 1
    fi
    
    return 0
}

# Export context to environment (for backward compatibility with existing code)
mlenv_context_export() {
    local -n _ctx_ref=$1
    
    export WORKDIR="${_ctx_ref[workdir]}"
    export PROJECT_NAME="${_ctx_ref[project_name]}"
    export WORKDIR_HASH="${_ctx_ref[workdir_hash]}"
    export CONTAINER_NAME="${_ctx_ref[container_name]}"
    export LOG_DIR="${_ctx_ref[log_dir]}"
    export LOG_FILE="${_ctx_ref[log_file]}"
    export REQUIREMENTS_MARKER="${_ctx_ref[requirements_marker]}"
    export IMAGE="${_ctx_ref[image]}"
    export REQUIREMENTS_PATH="${_ctx_ref[requirements_path]}"
    export FORCE_REQUIREMENTS="${_ctx_ref[force_requirements]}"
    export VERBOSE="${_ctx_ref[verbose]}"
    export PORTS="${_ctx_ref[ports]}"
    export JUPYTER_PORT="${_ctx_ref[jupyter_port]}"
    export GPU_DEVICES="${_ctx_ref[gpu_devices]}"
    export ENV_FILE="${_ctx_ref[env_file]}"
    export MEMORY_LIMIT="${_ctx_ref[memory_limit]}"
    export CPU_LIMIT="${_ctx_ref[cpu_limit]}"
    export RUN_AS_USER="${_ctx_ref[run_as_user]}"
    export EXEC_CMD="${_ctx_ref[exec_cmd]}"
    
    vlog "Context exported to environment variables"
}

# Get context value
mlenv_context_get() {
    local -n _ctx_ref=$1
    local _key="$2"
    local _default="${3:-}"
    
    if [[ -n "${_ctx_ref[$_key]:-}" ]]; then
        echo "${_ctx_ref[$_key]}"
    else
        echo "$_default"
    fi
}

# Set context value
mlenv_context_set() {
    local -n _ctx_ref=$1
    local _key="$2"
    local _value="$3"
    
    _ctx_ref[$_key]="$_value"
    vlog "Context: $_key = $_value"
}

# Print context for debugging
mlenv_context_print() {
    local -n _ctx_ref=$1
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MLEnv Context"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    echo "[Project]"
    echo "  workdir        = ${_ctx_ref[workdir]}"
    echo "  project_name   = ${_ctx_ref[project_name]}"
    echo "  container_name = ${_ctx_ref[container_name]}"
    
    echo ""
    echo "[Paths]"
    echo "  log_dir        = ${_ctx_ref[log_dir]}"
    echo "  log_file       = ${_ctx_ref[log_file]}"
    
    if [[ -n "${_ctx_ref[image]}" ]] || [[ -n "${_ctx_ref[gpu_devices]}" ]] || [[ -n "${_ctx_ref[ports]}" ]]; then
        echo ""
        echo "[Options]"
        [[ -n "${_ctx_ref[image]}" ]] && echo "  image          = ${_ctx_ref[image]}"
        [[ -n "${_ctx_ref[gpu_devices]}" ]] && echo "  gpu_devices    = ${_ctx_ref[gpu_devices]}"
        [[ -n "${_ctx_ref[ports]}" ]] && echo "  ports          = ${_ctx_ref[ports]}"
        [[ -n "${_ctx_ref[requirements_path]}" ]] && echo "  requirements   = ${_ctx_ref[requirements_path]}"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
