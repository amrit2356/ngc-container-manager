#!/usr/bin/env bash
# MLEnv Resource Tracker
# Version: 2.1.0
# Tracks allocated resources and ensures cleanup

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# Global resource tracking
declare -gA MLENV_TRACKED_RESOURCES=()
declare -g MLENV_RESOURCE_TRACKING_ENABLED=false

# Initialize resource tracking
resource_tracking_init() {
    MLENV_RESOURCE_TRACKING_ENABLED=true
    MLENV_TRACKED_RESOURCES=()
    
    # Set trap for cleanup on exit
    trap 'resource_tracking_cleanup_all' EXIT
    
    vlog "Resource tracking initialized"
}

# Disable resource tracking
resource_tracking_disable() {
    MLENV_RESOURCE_TRACKING_ENABLED=false
    trap - EXIT
    vlog "Resource tracking disabled"
}

# Track a resource
# Arguments:
#   $1: resource type (temp_file, gpu, port, container, image)
#   $2: resource identifier
#   $3: cleanup command (optional, auto-generated if not provided)
# Returns: 0 on success
resource_track() {
    local resource_type="$1"
    local resource_id="$2"
    local cleanup_cmd="${3:-}"
    
    if [[ "$MLENV_RESOURCE_TRACKING_ENABLED" != "true" ]]; then
        return 0
    fi
    
    if [[ -z "$resource_type" ]] || [[ -z "$resource_id" ]]; then
        error "resource_track: type and ID required"
        return 1
    fi
    
    # Auto-generate cleanup command if not provided
    if [[ -z "$cleanup_cmd" ]]; then
        case "$resource_type" in
            temp_file)
                cleanup_cmd="rm -f '$resource_id'"
                ;;
            temp_dir)
                cleanup_cmd="rm -rf '$resource_id'"
                ;;
            gpu)
                cleanup_cmd="resource_release_gpu '$resource_id'"
                ;;
            port)
                cleanup_cmd="resource_release_port '$resource_id'"
                ;;
            container)
                cleanup_cmd="docker rm -f '$resource_id' 2>/dev/null || true"
                ;;
            *)
                warn "Unknown resource type: $resource_type"
                return 1
                ;;
        esac
    fi
    
    local key="${resource_type}:${resource_id}"
    MLENV_TRACKED_RESOURCES["$key"]="$cleanup_cmd"
    
    vlog "Tracking resource: $key"
    return 0
}

# Untrack a resource (when properly cleaned up)
# Arguments:
#   $1: resource type
#   $2: resource identifier
resource_untrack() {
    local resource_type="$1"
    local resource_id="$2"
    
    local key="${resource_type}:${resource_id}"
    
    if [[ -n "${MLENV_TRACKED_RESOURCES[$key]:-}" ]]; then
        unset MLENV_TRACKED_RESOURCES["$key"]
        vlog "Untracked resource: $key"
    fi
}

# Clean up a specific resource
# Arguments:
#   $1: resource type
#   $2: resource identifier
resource_cleanup() {
    local resource_type="$1"
    local resource_id="$2"
    
    local key="${resource_type}:${resource_id}"
    local cleanup_cmd="${MLENV_TRACKED_RESOURCES[$key]:-}"
    
    if [[ -z "$cleanup_cmd" ]]; then
        vlog "Resource not tracked: $key"
        return 0
    fi
    
    vlog "Cleaning up resource: $key"
    
    if eval "$cleanup_cmd" 2>/dev/null; then
        vlog "  ✓ Cleanup succeeded"
        unset MLENV_TRACKED_RESOURCES["$key"]
        return 0
    else
        warn "  ✗ Cleanup failed: $cleanup_cmd"
        return 1
    fi
}

# Clean up all tracked resources
resource_tracking_cleanup_all() {
    if [[ "$MLENV_RESOURCE_TRACKING_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local count=${#MLENV_TRACKED_RESOURCES[@]}
    
    if [[ $count -eq 0 ]]; then
        vlog "No resources to clean up"
        return 0
    fi
    
    vlog "Cleaning up $count tracked resources..."
    
    # Clean up in reverse order of tracking
    local keys=("${!MLENV_TRACKED_RESOURCES[@]}")
    for ((i=${#keys[@]}-1; i>=0; i--)); do
        local key="${keys[i]}"
        local cleanup_cmd="${MLENV_TRACKED_RESOURCES[$key]}"
        
        vlog "Cleanup: $key"
        if eval "$cleanup_cmd" 2>/dev/null; then
            vlog "  ✓ Success"
        else
            warn "  ✗ Failed: $cleanup_cmd"
        fi
    done
    
    MLENV_TRACKED_RESOURCES=()
    info "Resource cleanup complete"
}

# List tracked resources
resource_tracking_list() {
    if [[ ${#MLENV_TRACKED_RESOURCES[@]} -eq 0 ]]; then
        echo "No resources currently tracked"
        return 0
    fi
    
    echo "Tracked Resources:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for key in "${!MLENV_TRACKED_RESOURCES[@]}"; do
        local cleanup_cmd="${MLENV_TRACKED_RESOURCES[$key]}"
        echo "  $key"
        echo "    Cleanup: $cleanup_cmd"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: ${#MLENV_TRACKED_RESOURCES[@]} resources"
}

# Get count of tracked resources by type
resource_tracking_count() {
    local resource_type="${1:-}"
    
    if [[ -z "$resource_type" ]]; then
        echo "${#MLENV_TRACKED_RESOURCES[@]}"
        return 0
    fi
    
    local count=0
    for key in "${!MLENV_TRACKED_RESOURCES[@]}"; do
        if [[ "$key" =~ ^${resource_type}: ]]; then
            ((count++))
        fi
    done
    
    echo "$count"
}

# Helper: Release GPU allocation
resource_release_gpu() {
    local gpu_id="$1"
    
    if command -v db_execute >/dev/null 2>&1; then
        db_execute "DELETE FROM gpu_allocations WHERE gpu_id='$gpu_id'" 2>/dev/null || true
        vlog "Released GPU: $gpu_id"
    fi
}

# Helper: Release port allocation
resource_release_port() {
    local port="$1"
    
    # Port tracking could be implemented here
    # For now, just log
    vlog "Released port: $port"
}

# Detect leaked resources (resources that should have been cleaned up)
resource_detect_leaks() {
    echo "Detecting resource leaks..."
    echo ""
    
    local leaks_found=0
    
    # Check for orphaned temp files
    if [[ -d "${MLENV_VAR:-/var/mlenv}/tmp" ]]; then
        local old_files=$(find "${MLENV_VAR:-/var/mlenv}/tmp" -type f -mtime +7 2>/dev/null | wc -l)
        if [[ $old_files -gt 0 ]]; then
            warn "Found $old_files temp files older than 7 days"
            ((leaks_found++))
        fi
    fi
    
    # Check for stale lock files
    if [[ -d "${MLENV_LOCK_DIR:-/var/lock/mlenv}" ]]; then
        local stale_locks=0
        for lockfile in "${MLENV_LOCK_DIR:-/var/lock/mlenv}"/*.lock; do
            if [[ -f "$lockfile" ]]; then
                local pid=$(cat "$lockfile" 2>/dev/null)
                if [[ -n "$pid" ]] && ! ps -p "$pid" >/dev/null 2>&1; then
                    ((stale_locks++))
                fi
            fi
        done
        
        if [[ $stale_locks -gt 0 ]]; then
            warn "Found $stale_locks stale lock files"
            ((leaks_found++))
        fi
    fi
    
    # Check for orphaned GPU allocations
    if command -v db_query >/dev/null 2>&1; then
        local orphaned_gpus=$(db_query "SELECT COUNT(*) FROM gpu_allocations ga 
            WHERE NOT EXISTS (
                SELECT 1 FROM container_instances ci 
                WHERE ci.container_name = ga.container_name 
                AND ci.status = 'running'
            )" "-list" 2>/dev/null || echo "0")
        
        if [[ $orphaned_gpus -gt 0 ]]; then
            warn "Found $orphaned_gpus orphaned GPU allocations"
            ((leaks_found++))
        fi
    fi
    
    if [[ $leaks_found -eq 0 ]]; then
        success "No resource leaks detected"
    else
        warn "Found $leaks_found types of resource leaks"
        info "Run 'mlenv cleanup-leaked' to clean them up"
    fi
    
    return $leaks_found
}

# Clean up leaked resources
resource_cleanup_leaked() {
    echo "Cleaning up leaked resources..."
    echo ""
    
    local cleaned=0
    
    # Clean old temp files
    if [[ -d "${MLENV_VAR:-/var/mlenv}/tmp" ]]; then
        vlog "Cleaning temp files older than 7 days..."
        local count=$(find "${MLENV_VAR:-/var/mlenv}/tmp" -type f -mtime +7 -delete -print 2>/dev/null | wc -l)
        if [[ $count -gt 0 ]]; then
            info "✓ Cleaned $count temp files"
            ((cleaned++))
        fi
    fi
    
    # Clean stale locks
    if command -v lock_clean_stale >/dev/null 2>&1; then
        lock_clean_stale
        ((cleaned++))
    fi
    
    # Clean orphaned GPU allocations
    if command -v db_execute >/dev/null 2>&1; then
        vlog "Cleaning orphaned GPU allocations..."
        db_execute "DELETE FROM gpu_allocations 
            WHERE container_name NOT IN (
                SELECT container_name FROM container_instances WHERE status = 'running'
            )" 2>/dev/null || true
        info "✓ Cleaned orphaned GPU allocations"
        ((cleaned++))
    fi
    
    # Sync container states
    if command -v sync_all_containers >/dev/null 2>&1; then
        sync_all_containers >/dev/null 2>&1
        ((cleaned++))
    fi
    
    echo ""
    success "Leak cleanup complete ($cleaned operations performed)"
}

vlog "Resource tracker loaded"
