#!/usr/bin/env bash
# MLEnv Context Management
# Version: 2.0.0
# Provides structured context instead of global variables

# Create mlenv context
mlenv_context_create() {
    local -n ctx=$1
    
    # Environment
    ctx[version]="2.0.0"
    ctx[workdir]="${WORKDIR:-$(pwd)}"
    ctx[project_name]="$(basename "${ctx[workdir]}")"
    ctx[workdir_hash]="$(echo "${ctx[workdir]}" | md5sum | cut -c1-8)"
    
    # Container
    ctx[container_name]="mlenv-${ctx[project_name]}-${ctx[workdir_hash]}"
    
    # Paths
    ctx[log_dir]="${ctx[workdir]}/.mlenv"
    ctx[log_file]="${ctx[log_dir]}/mlenv.log"
    ctx[requirements_marker]="${ctx[log_dir]}/.requirements_installed"
    
    # Command-line options (populated from global vars for compatibility)
    ctx[image]="${IMAGE:-}"
    ctx[requirements_path]="${REQUIREMENTS_PATH:-}"
    ctx[force_requirements]="${FORCE_REQUIREMENTS:-false}"
    ctx[verbose]="${VERBOSE:-false}"
    ctx[ports]="${PORTS:-}"
    ctx[jupyter_port]="${JUPYTER_PORT:-}"
    ctx[gpu_devices]="${GPU_DEVICES:-}"
    ctx[env_file]="${ENV_FILE:-}"
    ctx[memory_limit]="${MEMORY_LIMIT:-}"
    ctx[cpu_limit]="${CPU_LIMIT:-}"
    ctx[run_as_user]="${RUN_AS_USER:-true}"
    ctx[exec_cmd]="${EXEC_CMD:-}"
    
    vlog "Context created for project: ${ctx[project_name]}"
}

# Validate context has required fields
mlenv_context_validate() {
    local -n ctx=$1
    
    if [[ -z "${ctx[workdir]}" ]]; then
        error "Context missing workdir"
        return 1
    fi
    
    if [[ -z "${ctx[container_name]}" ]]; then
        error "Context missing container_name"
        return 1
    fi
    
    if [[ -z "${ctx[project_name]}" ]]; then
        error "Context missing project_name"
        return 1
    fi
    
    return 0
}

# Export context to environment (for backward compatibility with existing code)
mlenv_context_export() {
    local -n ctx=$1
    
    export WORKDIR="${ctx[workdir]}"
    export PROJECT_NAME="${ctx[project_name]}"
    export WORKDIR_HASH="${ctx[workdir_hash]}"
    export CONTAINER_NAME="${ctx[container_name]}"
    export LOG_DIR="${ctx[log_dir]}"
    export LOG_FILE="${ctx[log_file]}"
    export REQUIREMENTS_MARKER="${ctx[requirements_marker]}"
    export IMAGE="${ctx[image]}"
    export REQUIREMENTS_PATH="${ctx[requirements_path]}"
    export FORCE_REQUIREMENTS="${ctx[force_requirements]}"
    export VERBOSE="${ctx[verbose]}"
    export PORTS="${ctx[ports]}"
    export JUPYTER_PORT="${ctx[jupyter_port]}"
    export GPU_DEVICES="${ctx[gpu_devices]}"
    export ENV_FILE="${ctx[env_file]}"
    export MEMORY_LIMIT="${ctx[memory_limit]}"
    export CPU_LIMIT="${ctx[cpu_limit]}"
    export RUN_AS_USER="${ctx[run_as_user]}"
    export EXEC_CMD="${ctx[exec_cmd]}"
    
    vlog "Context exported to environment variables"
}

# Get context value
mlenv_context_get() {
    local -n ctx=$1
    local key="$2"
    local default="${3:-}"
    
    if [[ -n "${ctx[$key]:-}" ]]; then
        echo "${ctx[$key]}"
    else
        echo "$default"
    fi
}

# Set context value
mlenv_context_set() {
    local -n ctx=$1
    local key="$2"
    local value="$3"
    
    ctx[$key]="$value"
    vlog "Context: $key = $value"
}

# Print context for debugging
mlenv_context_print() {
    local -n ctx=$1
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MLEnv Context"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    echo "[Project]"
    echo "  workdir        = ${ctx[workdir]}"
    echo "  project_name   = ${ctx[project_name]}"
    echo "  container_name = ${ctx[container_name]}"
    
    echo ""
    echo "[Paths]"
    echo "  log_dir        = ${ctx[log_dir]}"
    echo "  log_file       = ${ctx[log_file]}"
    
    if [[ -n "${ctx[image]}" ]] || [[ -n "${ctx[gpu_devices]}" ]] || [[ -n "${ctx[ports]}" ]]; then
        echo ""
        echo "[Options]"
        [[ -n "${ctx[image]}" ]] && echo "  image          = ${ctx[image]}"
        [[ -n "${ctx[gpu_devices]}" ]] && echo "  gpu_devices    = ${ctx[gpu_devices]}"
        [[ -n "${ctx[ports]}" ]] && echo "  ports          = ${ctx[ports]}"
        [[ -n "${ctx[requirements_path]}" ]] && echo "  requirements   = ${ctx[requirements_path]}"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
