#!/usr/bin/env bash
# MLEnv State Synchronization
# Version: 2.1.0
# Reconciles database state with Docker reality

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/database/init.sh"

# Synchronize single container state
# Arguments:
#   $1: container name
# Returns: 0 if synced, 1 on error
sync_container_state() {
    local container_name="$1"
    
    if [[ -z "$container_name" ]]; then
        error "sync_container_state: container name required"
        return 1
    fi
    
    vlog "Syncing state for container: $container_name"
    
    # Get actual Docker state
    local docker_exists=false
    local docker_status="absent"
    
    if container_exists "$container_name"; then
        docker_exists=true
        docker_status=$(container_get_status "$container_name")
    fi
    
    # Get database state
    local db_status=$(db_query "SELECT status FROM container_instances WHERE container_name='$container_name'" "-list" 2>/dev/null || echo "")
    
    # State reconciliation logic
    if [[ "$docker_exists" == "true" ]]; then
        if [[ -z "$db_status" ]]; then
            # Container exists in Docker but not in DB - add to DB
            warn "Container $container_name exists in Docker but not in database - adding entry"
            local container_id=$(docker inspect "$container_name" --format '{{.Id}}' 2>/dev/null)
            local image=$(docker inspect "$container_name" --format '{{.Config.Image}}' 2>/dev/null)
            local workdir=$(docker inspect "$container_name" --format '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)
            
            db_execute "INSERT INTO container_instances (container_id, container_name, image_name, project_path, status) VALUES ('$container_id', '$container_name', '$image', '$workdir', '$docker_status')" 2>/dev/null || {
                error "Failed to add container to database"
                return 1
            }
            info "✓ Added container to database"
        elif [[ "$db_status" != "$docker_status" ]]; then
            # Container exists in both but status differs - update DB
            warn "State mismatch: DB=$db_status, Docker=$docker_status - updating database"
            
            local update_time=""
            if [[ "$docker_status" == "running" ]]; then
                update_time=", started_at=datetime('now')"
            elif [[ "$docker_status" == "stopped" ]]; then
                update_time=", stopped_at=datetime('now')"
            fi
            
            db_execute "UPDATE container_instances SET status='$docker_status'${update_time} WHERE container_name='$container_name'" || {
                error "Failed to update container status"
                return 1
            }
            info "✓ Updated container status to: $docker_status"
        else
            vlog "Container state is synchronized"
        fi
    else
        if [[ -n "$db_status" ]]; then
            # Container in DB but not in Docker - mark as removed or delete
            warn "Container $container_name exists in database but not in Docker - removing entry"
            db_execute "DELETE FROM container_instances WHERE container_name='$container_name'" || {
                error "Failed to remove stale container entry"
                return 1
            }
            info "✓ Removed stale container entry from database"
        fi
    fi
    
    return 0
}

# Synchronize all container states
# Returns: number of discrepancies found
sync_all_containers() {
    vlog "Starting full container state synchronization..."
    
    local discrepancies=0
    
    # Get all containers from Docker
    local docker_containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep "^mlenv-" || true)
    
    # Get all containers from database
    local db_containers=$(db_query "SELECT container_name FROM container_instances" "-list" 2>/dev/null || true)
    
    # Sync containers from Docker
    if [[ -n "$docker_containers" ]]; then
        while IFS= read -r container_name; do
            if ! sync_container_state "$container_name"; then
                ((discrepancies++))
            fi
        done <<< "$docker_containers"
    fi
    
    # Sync containers from database (handle orphaned entries)
    if [[ -n "$db_containers" ]]; then
        while IFS= read -r container_name; do
            # Skip if already processed from Docker list
            if echo "$docker_containers" | grep -q "^${container_name}$"; then
                continue
            fi
            
            # This container is in DB but not in Docker
            if ! sync_container_state "$container_name"; then
                ((discrepancies++))
            fi
        done <<< "$db_containers"
    fi
    
    if [[ $discrepancies -eq 0 ]]; then
        success "All container states are synchronized"
    else
        warn "Found and fixed $discrepancies state discrepancies"
    fi
    
    return $discrepancies
}

# Synchronize GPU allocations
# Returns: 0 on success
sync_gpu_allocations() {
    vlog "Synchronizing GPU allocations..."
    
    # Check if gpu_allocations table exists
    local table_exists=$(db_query "SELECT name FROM sqlite_master WHERE type='table' AND name='gpu_allocations'" "-list" 2>/dev/null || echo "")
    
    if [[ -z "$table_exists" ]]; then
        vlog "GPU allocations table does not exist yet - skipping"
        return 0
    fi
    
    # Get all containers with GPU allocations in DB
    local allocated_containers=$(db_query "SELECT DISTINCT container_name FROM gpu_allocations" "-list" 2>/dev/null || true)
    
    if [[ -z "$allocated_containers" ]]; then
        vlog "No GPU allocations to sync"
        return 0
    fi
    
    # Clean up allocations for non-existent containers
    local cleaned=0
    while IFS= read -r container_name; do
        if ! container_exists "$container_name"; then
            warn "Releasing GPUs from non-existent container: $container_name"
            db_execute "DELETE FROM gpu_allocations WHERE container_name='$container_name'" 2>/dev/null || true
            ((cleaned++))
        fi
    done <<< "$allocated_containers"
    
    if [[ $cleaned -gt 0 ]]; then
        info "✓ Cleaned $cleaned stale GPU allocations"
    else
        vlog "GPU allocations are synchronized"
    fi
    
    return 0
}

# Full system synchronization
# Syncs containers, GPUs, and cleans stale data
sync_full_system() {
    echo ""
    log "▶ Starting full system synchronization..."
    echo ""
    
    # Sync container states
    local container_discrepancies=0
    if sync_all_containers; then
        container_discrepancies=$?
    fi
    
    # Sync GPU allocations
    sync_gpu_allocations
    
    # Clean up old metrics
    local retention_days="${MLENV_METRICS_RETENTION_DAYS:-7}"
    vlog "Cleaning metrics older than $retention_days days..."
    db_execute "DELETE FROM resource_metrics WHERE timestamp < datetime('now', '-${retention_days} days')" 2>/dev/null || true
    db_execute "DELETE FROM system_snapshots WHERE timestamp < datetime('now', '-${retention_days} days')" 2>/dev/null || true
    
    echo ""
    success "System synchronization complete"
    
    if [[ $container_discrepancies -gt 0 ]]; then
        info "Fixed $container_discrepancies container state issues"
    fi
    
    echo ""
}

# Quick sync check (for status command)
# Returns: 0 if in sync, 1 if discrepancies found
sync_quick_check() {
    local docker_count=$(docker ps -a --filter "name=^mlenv-" --format '{{.Names}}' 2>/dev/null | wc -l)
    local db_count=$(db_query "SELECT COUNT(*) FROM container_instances" "-list" 2>/dev/null || echo "0")
    
    if [[ "$docker_count" != "$db_count" ]]; then
        vlog "State discrepancy detected: Docker=$docker_count, DB=$db_count"
        return 1
    fi
    
    return 0
}

vlog "State synchronization utilities loaded"
