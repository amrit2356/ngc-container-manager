#!/usr/bin/env bash
# MLEnv Resource Monitoring
# Version: 2.0.0

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/database/init.sh"

# Get current system resource statistics
resource_get_system_stats() {
    local output_format="${1:-text}"  # text or json
    
    # CPU usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_cores=$(nproc)
    
    # Memory usage (GB)
    local mem_total=$(free -g | awk '/^Mem:/{print $2}')
    local mem_used=$(free -g | awk '/^Mem:/{print $3}')
    local mem_available=$(free -g | awk '/^Mem:/{print $7}')
    local mem_percent=$(awk "BEGIN {printf \"%.1f\", ($mem_used/$mem_total)*100}")
    
    # Load averages
    read load_1min load_5min load_15min _ _ < /proc/loadavg
    
    # GPU usage (if available)
    local gpu_json="[]"
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_stats=()
        while IFS=, read -r gpu_id gpu_util mem_used mem_total temp; do
            gpu_stats+=("{\"gpu_id\":$gpu_id,\"utilization\":$gpu_util,\"memory_used_mb\":$mem_used,\"memory_total_mb\":$mem_total,\"temperature\":$temp}")
        done < <(nvidia-smi --query-gpu=index,utilization.gpu,memory.used,memory.total,temperature.gpu \
            --format=csv,noheader,nounits 2>/dev/null)
        
        if [[ ${#gpu_stats[@]} -gt 0 ]]; then
            gpu_json="[$(IFS=,; echo "${gpu_stats[*]}")]"
        fi
    fi
    
    if [[ "$output_format" == "json" ]]; then
        cat <<EOF
{
    "cpu": {
        "usage_percent": $cpu_usage,
        "cores": $cpu_cores
    },
    "memory": {
        "total_gb": $mem_total,
        "used_gb": $mem_used,
        "available_gb": $mem_available,
        "usage_percent": $mem_percent
    },
    "load": {
        "1min": $load_1min,
        "5min": $load_5min,
        "15min": $load_15min
    },
    "gpus": $gpu_json,
    "timestamp": "$(date -Iseconds)"
}
EOF
    else
        echo "CPU: ${cpu_usage}% (${cpu_cores} cores)"
        echo "Memory: ${mem_used}GB / ${mem_total}GB (${mem_percent}%)"
        echo "Available: ${mem_available}GB"
        echo "Load: $load_1min, $load_5min, $load_15min"
        
        if [[ "$gpu_json" != "[]" ]]; then
            echo ""
            echo "GPUs:"
            nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total \
                --format=csv,noheader 2>/dev/null | while IFS=, read -r idx name util mem_used mem_total; do
                echo "  GPU $idx ($name): ${util}% util, ${mem_used} / ${mem_total}"
            done
        fi
    fi
}

# Record system snapshot to database
resource_record_snapshot() {
    vlog "Recording system snapshot..."
    
    # Get stats
    local stats
    stats=$(resource_get_system_stats json)
    
    # Parse with jq if available
    if command -v jq >/dev/null 2>&1; then
        local cpu_percent=$(echo "$stats" | jq -r '.cpu.usage_percent')
        local cpu_cores=$(echo "$stats" | jq -r '.cpu.cores')
        local mem_total=$(echo "$stats" | jq -r '.memory.total_gb')
        local mem_used=$(echo "$stats" | jq -r '.memory.used_gb')
        local mem_available=$(echo "$stats" | jq -r '.memory.available_gb')
        local mem_percent=$(echo "$stats" | jq -r '.memory.usage_percent')
        local load_1min=$(echo "$stats" | jq -r '.load."1min"')
        local load_5min=$(echo "$stats" | jq -r '.load."5min"')
        local load_15min=$(echo "$stats" | jq -r '.load."15min"')
        local gpu_stats=$(echo "$stats" | jq -c '.gpus')
        
        # Insert into database
        db_query "INSERT INTO system_snapshots 
            (cpu_percent, cpu_cores, memory_total_gb, memory_used_gb, memory_available_gb, 
             memory_percent, load_1min, load_5min, load_15min, gpu_stats)
            VALUES 
            ($cpu_percent, $cpu_cores, $mem_total, $mem_used, $mem_available, 
             $mem_percent, $load_1min, $load_5min, $load_15min, '$gpu_stats');" ""
        
        vlog "System snapshot recorded"
    else
        warn "jq not available - skipping snapshot recording"
    fi
}

# Get container resource usage
resource_get_container_stats() {
    local container_name="$1"
    local output_format="${2:-text}"  # text or json
    
    if ! docker stats --no-stream --format \
        "json" \
        "$container_name" 2>/dev/null; then
        return 1
    fi
}

# Record container metrics to database
resource_record_container_metrics() {
    local container_name="$1"
    
    # Get container ID from name
    local container_id
    container_id=$(docker ps --filter "name=${container_name}" --format "{{.ID}}" 2>/dev/null)
    
    if [[ -z "$container_id" ]]; then
        vlog "Container not running: $container_name"
        return 1
    fi
    
    # Get stats
    local stats
    stats=$(docker stats --no-stream --format \
        "{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" \
        "$container_name" 2>/dev/null)
    
    if [[ -z "$stats" ]]; then
        return 1
    fi
    
    IFS=',' read -r cpu_percent mem_usage net_io block_io <<< "$stats"
    
    # Parse memory usage (e.g., "1.5GiB / 16GiB")
    local mem_used=$(echo "$mem_usage" | awk '{print $1}' | sed 's/GiB//' | sed 's/MiB//')
    
    # Remove % from CPU
    cpu_percent=$(echo "$cpu_percent" | sed 's/%//')
    
    # Get GPU stats for this container (if available)
    local gpu_json="[]"
    if docker exec "$container_name" nvidia-smi \
        --query-gpu=index,utilization.gpu,memory.used,memory.total \
        --format=csv,noheader,nounits 2>/dev/null | head -1 >/dev/null; then
        gpu_json="[{\"gpu_id\":0,\"utilization\":$(docker exec "$container_name" nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)}]"
    fi
    
    # Insert into database
    db_query "INSERT INTO resource_metrics 
        (container_id, cpu_percent, memory_used_gb, gpu_metrics)
        VALUES 
        ('$container_id', $cpu_percent, $mem_used, '$gpu_json');" ""
    
    vlog "Recorded metrics for container: $container_name"
}

# Monitor all running containers
resource_monitor_containers() {
    vlog "Monitoring all containers..."
    
    # Get all MLEnv containers
    local containers
    containers=$(docker ps --filter "name=mlenv-" --format "{{.Names}}" 2>/dev/null)
    
    if [[ -z "$containers" ]]; then
        vlog "No MLEnv containers running"
        return 0
    fi
    
    # Record metrics for each
    while read -r container; do
        if [[ -n "$container" ]]; then
            resource_record_container_metrics "$container"
        fi
    done <<< "$containers"
}

# Continuous monitoring loop
resource_monitor_loop() {
    local interval="${1:-10}"  # seconds
    local duration="${2:-0}"   # 0 = infinite
    
    info "Starting resource monitor (interval: ${interval}s)"
    
    local iterations=0
    local max_iterations=$((duration / interval))
    
    while true; do
        # Record system snapshot
        resource_record_snapshot
        
        # Record container metrics
        resource_monitor_containers
        
        # Clean old data periodically (every 100 iterations)
        if (( iterations % 100 == 0 )); then
            resource_clean_old_data 7  # Keep 7 days
        fi
        
        ((iterations++))
        
        # Break if duration specified and reached
        if [[ $duration -gt 0 ]] && [[ $iterations -ge $max_iterations ]]; then
            break
        fi
        
        sleep "$interval"
    done
    
    info "Resource monitor stopped"
}

# Get resource usage history
resource_get_history() {
    local hours="${1:-1}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "System Resource History (last ${hours}h)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    db_query "SELECT 
        datetime(timestamp, 'localtime') as time,
        ROUND(cpu_percent, 1) as cpu_pct,
        ROUND(memory_percent, 1) as mem_pct,
        ROUND(memory_available_gb, 1) as mem_avail_gb,
        ROUND(load_1min, 2) as load
    FROM system_snapshots
    WHERE timestamp > datetime('now', '-${hours} hours')
    ORDER BY timestamp DESC
    LIMIT 20;" "-column"
}

# Get container resource history
resource_get_container_history() {
    local container_name="$1"
    local hours="${2:-1}"
    
    # Get container ID
    local container_id
    container_id=$(docker ps -a --filter "name=${container_name}" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [[ -z "$container_id" ]]; then
        error "Container not found: $container_name"
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Container: $container_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    db_query "SELECT 
        datetime(timestamp, 'localtime') as time,
        ROUND(cpu_percent, 1) as cpu_pct,
        ROUND(memory_used_gb, 2) as mem_gb
    FROM resource_metrics
    WHERE container_id = '$container_id'
    AND timestamp > datetime('now', '-${hours} hours')
    ORDER BY timestamp DESC
    LIMIT 20;" "-column"
}

# Clean old monitoring data
resource_clean_old_data() {
    local days="${1:-7}"
    
    vlog "Cleaning resource data older than $days days..."
    
    db_query "DELETE FROM resource_metrics WHERE timestamp < datetime('now', '-${days} days');" ""
    db_query "DELETE FROM system_snapshots WHERE timestamp < datetime('now', '-${days} days');" ""
    
    vlog "Old resource data cleaned"
}

# Get resource summary
resource_get_summary() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Resource Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Current Status:"
    resource_get_system_stats text
    
    echo ""
    echo "Last Hour Averages:"
    db_query "SELECT * FROM v_system_summary;" "-column"
    
    echo ""
    echo "Active Containers:"
    db_query "SELECT * FROM v_active_containers;" "-column"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
