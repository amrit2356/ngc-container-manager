#!/usr/bin/env bash
# MLEnv Container Health Monitoring
# Version: 2.0.0

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# Health check thresholds
HEALTH_CPU_CRITICAL=95
HEALTH_MEM_CRITICAL=95
HEALTH_GPU_CRITICAL=95

# Health check for single container
health_check_container() {
    local container_name="$1"
    
    vlog "Health checking container: $container_name"
    
    local issues=()
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo "UNHEALTHY: Container not running"
        return 1
    fi
    
    # Check resource usage
    local stats
    stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" "$container_name" 2>/dev/null)
    
    if [[ -n "$stats" ]]; then
        IFS=',' read -r cpu_percent mem_percent <<< "$stats"
        cpu_percent=$(echo "$cpu_percent" | sed 's/%//')
        mem_percent=$(echo "$mem_percent" | sed 's/%//')
        
        # Check CPU
        if (( $(echo "$cpu_percent > $HEALTH_CPU_CRITICAL" | bc -l 2>/dev/null || echo 0) )); then
            issues+=("HIGH CPU: ${cpu_percent}%")
        fi
        
        # Check memory
        if (( $(echo "$mem_percent > $HEALTH_MEM_CRITICAL" | bc -l 2>/dev/null || echo 0) )); then
            issues+=("HIGH MEMORY: ${mem_percent}%")
        fi
    fi
    
    # Check if container is responsive
    if ! docker exec "$container_name" echo "ping" >/dev/null 2>&1; then
        issues+=("NOT RESPONSIVE")
    fi
    
    # Check GPU (if available)
    if docker exec "$container_name" nvidia-smi >/dev/null 2>&1; then
        local gpu_util
        gpu_util=$(docker exec "$container_name" nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
        
        if [[ -n "$gpu_util" ]] && (( gpu_util > HEALTH_GPU_CRITICAL )); then
            issues+=("HIGH GPU: ${gpu_util}%")
        fi
    fi
    
    # Return health status
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "HEALTHY"
        return 0
    else
        echo "UNHEALTHY: ${issues[*]}"
        return 1
    fi
}

# Health check all MLEnv containers
health_check_all() {
    info "Checking health of all MLEnv containers..."
    echo ""
    
    local containers
    containers=$(docker ps --filter "name=mlenv-" --format "{{.Names}}" 2>/dev/null)
    
    if [[ -z "$containers" ]]; then
        info "No MLEnv containers running"
        return 0
    fi
    
    local healthy=0
    local unhealthy=0
    
    while read -r container; do
        if [[ -z "$container" ]]; then continue; fi
        
        echo -n "  $container ... "
        local health_status
        health_status=$(health_check_container "$container")
        
        if [[ "$health_status" == "HEALTHY" ]]; then
            echo "✓ $health_status"
            ((healthy++))
        else
            echo "✗ $health_status"
            ((unhealthy++))
        fi
    done <<< "$containers"
    
    echo ""
    echo "Summary: $healthy healthy, $unhealthy unhealthy"
    
    return $unhealthy
}

# Continuous health monitoring
health_monitor_loop() {
    local interval="${1:-30}"  # seconds
    
    info "Starting health monitor (interval: ${interval}s)"
    
    while true; do
        health_check_all
        sleep "$interval"
    done
}

# Get container health report
health_get_report() {
    local container_name="$1"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Health Report: $container_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Status
    echo "Status: $(health_check_container "$container_name")"
    echo ""
    
    # Resource usage
    echo "Resource Usage:"
    docker stats --no-stream "$container_name" 2>/dev/null
    
    # GPU usage
    if docker exec "$container_name" nvidia-smi >/dev/null 2>&1; then
        echo ""
        echo "GPU Status:"
        docker exec "$container_name" nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total \
            --format=csv 2>/dev/null
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
