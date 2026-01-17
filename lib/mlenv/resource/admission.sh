#!/usr/bin/env bash
# MLEnv Admission Control - Prevents System Overload
# Version: 2.1.0
# Simplified admission control without full monitoring dependency

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# Safety thresholds (can be overridden by config)
readonly ADMISSION_MAX_MEMORY_PERCENT="${MLENV_MAX_MEMORY_PERCENT:-85}"
readonly ADMISSION_MIN_AVAILABLE_MEMORY_GB="${MLENV_MIN_AVAILABLE_MEMORY_GB:-4}"
readonly ADMISSION_MAX_CPU_PERCENT="${MLENV_MAX_CPU_PERCENT:-90}"
readonly ADMISSION_MAX_LOAD_MULTIPLIER="${MLENV_MAX_LOAD_MULTIPLIER:-2}"

# Get current system memory stats
# Returns: total_gb used_gb available_gb percent
_admission_get_memory_stats() {
    if command -v free >/dev/null 2>&1; then
        # Linux
        local mem_info=$(free -g | awk '/^Mem:/ {print $2,$3,$7,int($3/$2*100)}')
        echo "$mem_info"
    elif command -v vm_stat >/dev/null 2>&1; then
        # macOS
        local page_size=$(vm_stat | awk '/page size/ {print $8}')
        local pages_free=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
        local pages_active=$(vm_stat | awk '/Pages active/ {print $3}' | tr -d '.')
        local pages_inactive=$(vm_stat | awk '/Pages inactive/ {print $3}' | tr -d '.')
        
        local total_gb=$(echo "scale=2; ($pages_free + $pages_active + $pages_inactive) * $page_size / 1024 / 1024 / 1024" | bc)
        local used_gb=$(echo "scale=2; ($pages_active + $pages_inactive) * $page_size / 1024 / 1024 / 1024" | bc)
        local available_gb=$(echo "scale=2; $pages_free * $page_size / 1024 / 1024 / 1024" | bc)
        local percent=$(echo "scale=0; $used_gb / $total_gb * 100" | bc)
        
        echo "$total_gb $used_gb $available_gb $percent"
    else
        # Fallback - assume system is OK
        echo "0 0 999 0"
    fi
}

# Get CPU usage percentage
_admission_get_cpu_usage() {
    if command -v top >/dev/null 2>&1; then
        # Use top for quick CPU reading
        local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
        if [[ -n "$cpu_idle" ]]; then
            echo "scale=1; 100 - $cpu_idle" | bc
        else
            echo "0"
        fi
    elif command -v mpstat >/dev/null 2>&1; then
        # Use mpstat if available
        mpstat 1 1 | awk '/Average/ {print 100 - $NF}'
    else
        # Fallback
        echo "0"
    fi
}

# Get load average
_admission_get_load() {
    if [[ -f /proc/loadavg ]]; then
        cut -d' ' -f1 /proc/loadavg
    elif command -v uptime >/dev/null 2>&1; then
        uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' '
    else
        echo "0"
    fi
}

# Get CPU core count
_admission_get_cpu_cores() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif [[ -f /proc/cpuinfo ]]; then
        grep -c ^processor /proc/cpuinfo
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu 2>/dev/null || echo "1"
    else
        echo "1"
    fi
}

# Check if container creation should be admitted
# Arguments:
#   $1: container name
#   $2: requested memory (optional, e.g., "16g")
#   $3: requested CPU cores (optional, e.g., "4")
#   $4: requested GPUs (optional, e.g., "0,1" or "all")
# Returns: 0 if admitted, 1 if rejected
admission_check_container_creation() {
    local container_name="$1"
    local requested_memory="${2:-}"
    local requested_cpu="${3:-}"
    local requested_gpus="${4:-}"
    
    vlog "Admission control: checking if container can be created"
    vlog "  Container: $container_name"
    vlog "  Requested: mem=$requested_memory cpu=$requested_cpu gpus=$requested_gpus"
    
    local errors=()
    
    # Get system stats
    read -r total_mem used_mem available_mem mem_percent <<< "$(_admission_get_memory_stats)"
    local cpu_percent=$(_admission_get_cpu_usage)
    local load_avg=$(_admission_get_load)
    local cpu_cores=$(_admission_get_cpu_cores)
    
    vlog "  System: mem=${mem_percent}% (${available_mem}GB avail) cpu=${cpu_percent}% load=${load_avg}"
    
    # Check memory percentage threshold
    if (( $(echo "$mem_percent > $ADMISSION_MAX_MEMORY_PERCENT" | bc -l 2>/dev/null || echo "0") )); then
        errors+=("System memory usage too high: ${mem_percent}% > ${ADMISSION_MAX_MEMORY_PERCENT}%")
    fi
    
    # Check minimum available memory
    if (( $(echo "$available_mem < $ADMISSION_MIN_AVAILABLE_MEMORY_GB" | bc -l 2>/dev/null || echo "0") )); then
        errors+=("Insufficient available memory: ${available_mem}GB < ${ADMISSION_MIN_AVAILABLE_MEMORY_GB}GB")
    fi
    
    # Check CPU usage threshold
    if (( $(echo "$cpu_percent > $ADMISSION_MAX_CPU_PERCENT" | bc -l 2>/dev/null || echo "0") )); then
        errors+=("CPU usage too high: ${cpu_percent}% > ${ADMISSION_MAX_CPU_PERCENT}%")
    fi
    
    # Check load average
    local max_load=$(echo "$cpu_cores * $ADMISSION_MAX_LOAD_MULTIPLIER" | bc -l 2>/dev/null || echo "999")
    if (( $(echo "$load_avg > $max_load" | bc -l 2>/dev/null || echo "0") )); then
        errors+=("Load average too high: ${load_avg} > ${max_load} (${cpu_cores} cores × ${ADMISSION_MAX_LOAD_MULTIPLIER})")
    fi
    
    # Return result
    if [[ ${#errors[@]} -eq 0 ]]; then
        vlog "Admission check: PASSED"
        return 0
    else
        echo ""
        error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        error "Admission Control: Container creation REJECTED"
        error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        for err in "${errors[@]}"; do
            error "  ✗ $err"
        done
        echo ""
        info "System Resources:"
        info "  Memory: ${mem_percent}% used, ${available_mem}GB available"
        info "  CPU: ${cpu_percent}% usage"
        info "  Load: ${load_avg} (${cpu_cores} cores)"
        echo ""
        info "To bypass admission control, set:"
        info "  export MLENV_ENABLE_ADMISSION_CONTROL=false"
        echo ""
        error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        return 1
    fi
}

# Quick system health check (less strict than admission)
# Returns: 0 if healthy, 1 if critical
admission_system_health_check() {
    vlog "Performing system health check..."
    
    read -r total_mem used_mem available_mem mem_percent <<< "$(_admission_get_memory_stats)"
    local cpu_percent=$(_admission_get_cpu_usage)
    
    # Critical: Less than 2GB available
    if (( $(echo "$available_mem < 2" | bc -l 2>/dev/null || echo "0") )); then
        error "CRITICAL: System memory critically low (${available_mem}GB available)"
        return 1
    fi
    
    # Critical: CPU maxed out
    if (( $(echo "$cpu_percent > 95" | bc -l 2>/dev/null || echo "0") )); then
        error "CRITICAL: CPU usage critically high (${cpu_percent}%)"
        return 1
    fi
    
    vlog "System health check: PASSED"
    return 0
}

# Check if admission control is enabled
admission_is_enabled() {
    local enabled="${MLENV_ENABLE_ADMISSION_CONTROL:-false}"
    [[ "$enabled" == "true" ]]
}

vlog "Admission control loaded (thresholds: mem=${ADMISSION_MAX_MEMORY_PERCENT}%, cpu=${ADMISSION_MAX_CPU_PERCENT}%)"
