#!/usr/bin/env bash
# MLEnv Admission Control - Prevents System Overload
# Version: 2.0.0

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/resource/monitor.sh"

# Safety thresholds (can be overridden by config)
MAX_MEMORY_PERCENT="${MLENV_MAX_MEMORY_PERCENT:-85}"
MIN_AVAILABLE_MEMORY_GB="${MLENV_MIN_AVAILABLE_MEMORY_GB:-4}"
MAX_CPU_PERCENT="${MLENV_MAX_CPU_PERCENT:-90}"
MAX_LOAD_MULTIPLIER="${MLENV_MAX_LOAD_MULTIPLIER:-2}"  # 2x CPU cores

# Check if container can be admitted
admission_check() {
    local requested_memory_gb="${1:-0}"
    local requested_cpu_cores="${2:-0}"
    local requested_gpus="${3:-0}"
    
    vlog "Admission check: mem=${requested_memory_gb}GB cpu=${requested_cpu_cores} gpus=${requested_gpus}"
    
    local errors=()
    
    # Get current system stats
    local stats
    stats=$(resource_get_system_stats json)
    
    if ! command -v jq >/dev/null 2>&1; then
        warn "jq not available - admission control disabled"
        echo "ADMITTED"
        return 0
    fi
    
    local cpu_percent=$(echo "$stats" | jq -r '.cpu.usage_percent')
    local cpu_cores=$(echo "$stats" | jq -r '.cpu.cores')
    local mem_percent=$(echo "$stats" | jq -r '.memory.usage_percent')
    local mem_available=$(echo "$stats" | jq -r '.memory.available_gb')
    local mem_total=$(echo "$stats" | jq -r '.memory.total_gb')
    local load_1min=$(echo "$stats" | jq -r '.load."1min"')
    
    # Check memory percentage
    if (( $(echo "$mem_percent > $MAX_MEMORY_PERCENT" | bc -l) )); then
        errors+=("System memory usage too high: ${mem_percent}% > ${MAX_MEMORY_PERCENT}%")
    fi
    
    # Check available memory
    if (( $(echo "$mem_available < $MIN_AVAILABLE_MEMORY_GB" | bc -l) )); then
        errors+=("Insufficient available memory: ${mem_available}GB < ${MIN_AVAILABLE_MEMORY_GB}GB")
    fi
    
    # Check if requested memory exceeds available
    if (( $(echo "$requested_memory_gb > 0" | bc -l) )) && \
       (( $(echo "$requested_memory_gb > $mem_available" | bc -l) )); then
        errors+=("Requested memory (${requested_memory_gb}GB) exceeds available (${mem_available}GB)")
    fi
    
    # Check CPU usage
    if (( $(echo "$cpu_percent > $MAX_CPU_PERCENT" | bc -l) )); then
        errors+=("CPU usage too high: ${cpu_percent}% > ${MAX_CPU_PERCENT}%")
    fi
    
    # Check load average
    local max_load=$(echo "$cpu_cores * $MAX_LOAD_MULTIPLIER" | bc -l)
    if (( $(echo "$load_1min > $max_load" | bc -l) )); then
        errors+=("Load average too high: $load_1min > $max_load (${cpu_cores} cores * ${MAX_LOAD_MULTIPLIER})")
    fi
    
    # Check GPU availability
    if [[ "$requested_gpus" != "0" ]] && [[ "$requested_gpus" != "all" ]]; then
        local gpus_available
        gpus_available=$(echo "$stats" | jq -r '[.gpus[] | select(.utilization < 50)] | length')
        
        if (( requested_gpus > gpus_available )); then
            errors+=("Requested GPUs ($requested_gpus) exceeds available ($gpus_available with <50% utilization)")
        fi
    fi
    
    # Return result
    if [[ ${#errors[@]} -eq 0 ]]; then
        vlog "Admission check: ADMITTED"
        echo "ADMITTED"
        return 0
    else
        for err in "${errors[@]}"; do
            warn "Admission rejected: $err"
        done
        echo "REJECTED: ${errors[0]}"
        return 1
    fi
}

# Check project quota
admission_check_project_quota() {
    local project_path="$1"
    local requested_containers="${2:-1}"
    
    vlog "Checking project quota for: $project_path"
    
    # Get current quota
    local quota
    quota=$(db_query "SELECT 
        max_containers,
        current_containers,
        max_containers - current_containers as available
    FROM project_quotas
    WHERE project_path = '$project_path';" "")
    
    if [[ -z "$quota" ]]; then
        # No quota set, initialize with defaults
        admission_init_project_quota "$project_path"
        return 0
    fi
    
    IFS='|' read -r max_containers current_containers available <<< "$quota"
    
    if (( available < requested_containers )); then
        warn "Project quota exceeded: $current_containers/$max_containers containers"
        return 1
    fi
    
    return 0
}

# Initialize project quota
admission_init_project_quota() {
    local project_path="$1"
    local max_containers="${2:-5}"
    local max_cpu="${3:-16}"
    local max_memory="${4:-64}"
    local max_gpus="${5:-4}"
    
    vlog "Initializing quota for project: $project_path"
    
    db_query "INSERT OR IGNORE INTO project_quotas 
        (project_path, max_containers, max_cpu_cores, max_memory_gb, max_gpus)
        VALUES 
        ('$project_path', $max_containers, $max_cpu, $max_memory, $max_gpus);" ""
    
    vlog "Project quota initialized"
}

# Update project quota usage
admission_update_project_quota() {
    local project_path="$1"
    local delta_containers="${2:-0}"
    local delta_cpus="${3:-0}"
    local delta_memory="${4:-0}"
    local delta_gpus="${5:-0}"
    
    vlog "Updating project quota: containers=$delta_containers"
    
    # Ensure quota exists
    admission_init_project_quota "$project_path"
    
    # Update
    db_query "UPDATE project_quotas SET
        current_containers = current_containers + $delta_containers,
        current_cpu_cores = current_cpu_cores + $delta_cpus,
        current_memory_gb = current_memory_gb + $delta_memory,
        current_gpus = current_gpus + $delta_gpus
    WHERE project_path = '$project_path';" ""
    
    vlog "Project quota updated"
}

# Get project quota info
admission_get_project_quota() {
    local project_path="$1"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Project Quota: $project_path"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    db_query "SELECT 
        current_containers || '/' || max_containers as containers,
        ROUND(current_cpu_cores, 1) || '/' || max_cpu_cores as cpu_cores,
        ROUND(current_memory_gb, 1) || '/' || max_memory_gb as memory_gb,
        current_gpus || '/' || max_gpus as gpus
    FROM project_quotas
    WHERE project_path = '$project_path';" "-column"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Reset project quota
admission_reset_project_quota() {
    local project_path="$1"
    
    vlog "Resetting project quota: $project_path"
    
    db_query "UPDATE project_quotas SET
        current_containers = 0,
        current_cpu_cores = 0,
        current_memory_gb = 0,
        current_gpus = 0
    WHERE project_path = '$project_path';" ""
    
    success "Project quota reset"
}

# Check if system is healthy for new workload
admission_system_health_check() {
    vlog "Performing system health check..."
    
    local stats
    stats=$(resource_get_system_stats json)
    
    if ! command -v jq >/dev/null 2>&1; then
        warn "jq not available - health check skipped"
        return 0
    fi
    
    local mem_available=$(echo "$stats" | jq -r '.memory.available_gb')
    local cpu_percent=$(echo "$stats" | jq -r '.cpu.usage_percent')
    
    # Critical: Less than 2GB available
    if (( $(echo "$mem_available < 2" | bc -l) )); then
        error "CRITICAL: System memory critically low (${mem_available}GB available)"
        return 1
    fi
    
    # Critical: CPU maxed out
    if (( $(echo "$cpu_percent > 95" | bc -l) )); then
        error "CRITICAL: CPU usage critically high (${cpu_percent}%)"
        return 1
    fi
    
    vlog "System health check passed"
    return 0
}

# Get admission control statistics
admission_get_stats() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Admission Control Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Memory Threshold: $MAX_MEMORY_PERCENT%"
    echo "Min Available Memory: ${MIN_AVAILABLE_MEMORY_GB}GB"
    echo "CPU Threshold: $MAX_CPU_PERCENT%"
    echo "Load Multiplier: ${MAX_LOAD_MULTIPLIER}x"
    echo ""
    
    echo "Current System Status:"
    resource_get_system_stats text
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Dry-run admission check (for testing)
admission_check_dry_run() {
    local requested_memory_gb="${1:-8}"
    local requested_cpu_cores="${2:-4}"
    local requested_gpus="${3:-1}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Admission Control Dry Run"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Requested Resources:"
    echo "  Memory: ${requested_memory_gb}GB"
    echo "  CPU Cores: $requested_cpu_cores"
    echo "  GPUs: $requested_gpus"
    echo ""
    
    local result
    result=$(admission_check "$requested_memory_gb" "$requested_cpu_cores" "$requested_gpus")
    
    echo "Result: $result"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ "$result" == "ADMITTED" ]]; then
        return 0
    else
        return 1
    fi
}
