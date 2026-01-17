#!/usr/bin/env bash
# MLEnv Database Initialization
# Version: 2.1.0

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/utils/locking.sh"

# Database paths
MLENV_DB_DIR="${MLENV_VAR:-$HOME/.mlenv}/registry"
MLENV_DB_FILE="${MLENV_DB_DIR}/catalog.db"
MLENV_SCHEMA_FILE="${MLENV_LIB}/database/schema.sql"

# Initialize database
db_init() {
    vlog "Initializing MLEnv database..."
    
    # Create database directory
    if [[ ! -d "$MLENV_DB_DIR" ]]; then
        mkdir -p "$MLENV_DB_DIR" || {
            die "Failed to create database directory: $MLENV_DB_DIR"
        }
        vlog "Created database directory: $MLENV_DB_DIR"
    fi
    
    # Check if database exists
    if [[ -f "$MLENV_DB_FILE" ]]; then
        vlog "Database already exists: $MLENV_DB_FILE"
        
        # Verify database integrity
        if ! db_check; then
            warn "Database integrity check failed - attempting recovery"
            if ! db_recover_from_backup; then
                error "Database recovery failed - reinitializing"
                mv "$MLENV_DB_FILE" "${MLENV_DB_FILE}.corrupted.$(date +%s)"
                # Continue to create new database
            else
                return 0
            fi
        else
            return 0
        fi
    fi
    
    # Create database from schema
    if [[ ! -f "$MLENV_SCHEMA_FILE" ]]; then
        die "Database schema not found: $MLENV_SCHEMA_FILE"
    fi
    
    vlog "Creating database from schema..."
    if sqlite3 "$MLENV_DB_FILE" < "$MLENV_SCHEMA_FILE" 2>&1 | tee -a "${MLENV_LOG_FILE:-/dev/null}"; then
        success "Database initialized: $MLENV_DB_FILE"
        # Create initial backup
        db_auto_backup
    else
        die "Failed to initialize database"
    fi
}

# Check if database is accessible
db_check() {
    if [[ ! -f "$MLENV_DB_FILE" ]]; then
        return 1
    fi
    
    # Try a simple query
    if sqlite3 "$MLENV_DB_FILE" "SELECT 1;" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Execute SQL query (without lock - internal use)
_db_query_unlocked() {
    local query="$1"
    local format="${2:--column}"  # -column, -json, -csv, etc.
    
    if ! db_check; then
        db_init
    fi
    
    sqlite3 $format "$MLENV_DB_FILE" "$query"
}

# Track write operations for periodic backup
declare -g MLENV_DB_WRITE_COUNT=0
declare -g MLENV_DB_BACKUP_INTERVAL="${MLENV_DB_BACKUP_INTERVAL:-100}"

# Execute SQL query (with lock for safety)
db_query() {
    local query="$1"
    local format="${2:--column}"
    
    # Check if locking is enabled (default: true)
    local enable_locks="${MLENV_ENABLE_DB_LOCKS:-true}"
    
    if [[ "$enable_locks" != "true" ]]; then
        _db_query_unlocked "$query" "$format"
        return $?
    fi
    
    # Use lock for write operations (INSERT, UPDATE, DELETE, CREATE, ALTER, DROP)
    if [[ "$query" =~ ^[[:space:]]*(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|REPLACE) ]]; then
        local timeout="${MLENV_LOCK_TIMEOUT:-30}"
        
        # Acquire lock
        if ! lock_acquire "database" "$timeout"; then
            error "Failed to acquire database lock"
            return 1
        fi
        
        # Execute query
        local exit_code=0
        _db_query_unlocked "$query" "$format" || exit_code=$?
        
        # Release lock
        lock_release "database"
        
        # Periodic backup after N write operations
        if [[ $exit_code -eq 0 ]]; then
            ((MLENV_DB_WRITE_COUNT++))
            if (( MLENV_DB_WRITE_COUNT >= MLENV_DB_BACKUP_INTERVAL )); then
                db_auto_backup >/dev/null 2>&1 &
                MLENV_DB_WRITE_COUNT=0
            fi
        fi
        
        return $exit_code
    else
        # Read operations don't need exclusive lock
        _db_query_unlocked "$query" "$format"
    fi
}

# Execute SQL statement (alias for db_query with no format)
db_execute() {
    local query="$1"
    db_query "$query" ""
}

# Execute SQL from file
db_exec_file() {
    local sql_file="$1"
    
    if [[ ! -f "$sql_file" ]]; then
        error "SQL file not found: $sql_file"
        return 1
    fi
    
    if ! db_check; then
        db_init
    fi
    
    sqlite3 "$MLENV_DB_FILE" < "$sql_file"
}

# Insert data
db_insert() {
    local table="$1"
    local columns="$2"
    local values="$3"
    
    local query="INSERT INTO $table ($columns) VALUES ($values);"
    db_query "$query" ""
}

# Update data
db_update() {
    local table="$1"
    local set_clause="$2"
    local where_clause="$3"
    
    local query="UPDATE $table SET $set_clause WHERE $where_clause;"
    db_query "$query" ""
}

# Delete data
db_delete() {
    local table="$1"
    local where_clause="$2"
    
    local query="DELETE FROM $table WHERE $where_clause;"
    db_query "$query" ""
}

# Get database size
db_size() {
    if [[ -f "$MLENV_DB_FILE" ]]; then
        du -h "$MLENV_DB_FILE" | cut -f1
    else
        echo "0"
    fi
}

# Vacuum database (optimize)
db_vacuum() {
    vlog "Vacuuming database..."
    db_query "VACUUM;" ""
    success "Database optimized"
}

# Backup database
db_backup() {
    local backup_file="${1:-${MLENV_DB_FILE}.backup}"
    
    vlog "Backing up database to: $backup_file"
    
    if cp "$MLENV_DB_FILE" "$backup_file"; then
        success "Database backed up: $backup_file"
    else
        error "Failed to backup database"
        return 1
    fi
}

# Restore database from backup
db_restore() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        die "Backup file not found: $backup_file"
    fi
    
    vlog "Restoring database from: $backup_file"
    
    # Backup current database first
    if [[ -f "$MLENV_DB_FILE" ]]; then
        mv "$MLENV_DB_FILE" "${MLENV_DB_FILE}.old"
    fi
    
    if cp "$backup_file" "$MLENV_DB_FILE"; then
        success "Database restored from: $backup_file"
    else
        # Restore old database if copy failed
        if [[ -f "${MLENV_DB_FILE}.old" ]]; then
            mv "${MLENV_DB_FILE}.old" "$MLENV_DB_FILE"
        fi
        die "Failed to restore database"
    fi
}

# Clean old data
db_clean_old_data() {
    local days="${1:-30}"
    
    vlog "Cleaning data older than $days days..."
    
    # Clean old resource metrics
    db_query "DELETE FROM resource_metrics WHERE timestamp < datetime('now', '-${days} days');" ""
    
    # Clean old system snapshots
    db_query "DELETE FROM system_snapshots WHERE timestamp < datetime('now', '-${days} days');" ""
    
    # Clean expired API cache
    db_query "DELETE FROM api_cache WHERE expires_at < datetime('now');" ""
    
    success "Old data cleaned"
    
    # Vacuum to reclaim space
    db_vacuum
}

# Get database stats
db_stats() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MLEnv Database Statistics"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Database: $MLENV_DB_FILE"
    echo "Size: $(db_size)"
    echo ""
    
    # Table counts
    echo "Table Counts:"
    db_query "SELECT 
        (SELECT COUNT(*) FROM ngc_images) as images,
        (SELECT COUNT(*) FROM image_versions) as versions,
        (SELECT COUNT(*) FROM container_instances) as containers,
        (SELECT COUNT(*) FROM resource_metrics) as metrics,
        (SELECT COUNT(*) FROM system_snapshots) as snapshots;" "-column"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Export to JSON
db_export_json() {
    local table="$1"
    local output_file="${2:-${table}.json}"
    
    vlog "Exporting $table to JSON..."
    
    db_query "SELECT * FROM $table;" "-json" > "$output_file"
    
    if [[ $? -eq 0 ]]; then
        success "Exported to: $output_file"
    else
        error "Failed to export $table"
        return 1
    fi
}

# Auto-backup database (called periodically)
db_auto_backup() {
    local backup_dir="${MLENV_DB_DIR}/backups"
    local max_backups="${MLENV_DB_MAX_BACKUPS:-5}"
    
    # Create backup directory
    mkdir -p "$backup_dir" 2>/dev/null || return 0
    
    # Generate backup filename with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/catalog_${timestamp}.db"
    
    vlog "Auto-backup: $backup_file"
    
    # Create backup
    if cp "$MLENV_DB_FILE" "$backup_file" 2>/dev/null; then
        vlog "✓ Database backed up"
        
        # Clean old backups (keep only last N)
        local backup_count=$(ls -1 "$backup_dir"/catalog_*.db 2>/dev/null | wc -l)
        if (( backup_count > max_backups )); then
            local to_delete=$((backup_count - max_backups))
            ls -1t "$backup_dir"/catalog_*.db | tail -n "$to_delete" | xargs rm -f 2>/dev/null
            vlog "Cleaned $to_delete old backups"
        fi
    else
        vlog "Auto-backup failed (non-critical)"
    fi
}

# Recover database from most recent backup
db_recover_from_backup() {
    local backup_dir="${MLENV_DB_DIR}/backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        error "No backup directory found"
        return 1
    fi
    
    # Find most recent backup
    local latest_backup=$(ls -1t "$backup_dir"/catalog_*.db 2>/dev/null | head -1)
    
    if [[ -z "$latest_backup" ]]; then
        error "No backup files found"
        return 1
    fi
    
    warn "Recovering database from backup: $(basename "$latest_backup")"
    
    # Backup corrupted database
    if [[ -f "$MLENV_DB_FILE" ]]; then
        mv "$MLENV_DB_FILE" "${MLENV_DB_FILE}.corrupted.$(date +%s)"
    fi
    
    # Restore from backup
    if cp "$latest_backup" "$MLENV_DB_FILE"; then
        success "Database recovered from backup"
        return 0
    else
        error "Failed to restore from backup"
        return 1
    fi
}

# Check database integrity
db_integrity_check() {
    vlog "Checking database integrity..."
    
    local result=$(sqlite3 "$MLENV_DB_FILE" "PRAGMA integrity_check;" 2>/dev/null)
    
    if [[ "$result" == "ok" ]]; then
        vlog "Database integrity: OK"
        return 0
    else
        error "Database integrity check failed: $result"
        return 1
    fi
}

# Periodic maintenance (backup + cleanup)
db_maintenance() {
    vlog "Running database maintenance..."
    
    # Create backup
    db_auto_backup
    
    # Check integrity
    if ! db_integrity_check; then
        warn "Database integrity issues detected"
    fi
    
    # Clean old data
    local retention_days="${MLENV_METRICS_RETENTION_DAYS:-7}"
    db_clean_old_data "$retention_days" >/dev/null 2>&1
    
    vlog "Database maintenance complete"
}
