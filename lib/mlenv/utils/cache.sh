#!/usr/bin/env bash
# MLEnv Caching Layer
# Version: 2.0.0
# Provides simple file-based caching for performance

# Cache configuration
MLENV_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mlenv"
MLENV_CACHE_TTL="${MLENV_CACHE_TTL:-5}"  # seconds

# Initialize cache directory
cache_init() {
    mkdir -p "$MLENV_CACHE_DIR" 2>/dev/null || true
    vlog "Cache initialized: $MLENV_CACHE_DIR"
}

# Get cached value
cache_get() {
    local key="$1"
    local cache_file="$MLENV_CACHE_DIR/${key}.cache"
    
    # Check if cache exists and is fresh
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt $MLENV_CACHE_TTL ]]; then
            cat "$cache_file"
            vlog "Cache hit: $key (age: ${cache_age}s)"
            return 0
        else
            vlog "Cache expired: $key (age: ${cache_age}s, ttl: ${MLENV_CACHE_TTL}s)"
        fi
    else
        vlog "Cache miss: $key"
    fi
    
    return 1
}

# Set cached value
cache_set() {
    local key="$1"
    local value="$2"
    
    cache_init
    echo "$value" > "$MLENV_CACHE_DIR/${key}.cache"
    vlog "Cache set: $key"
}

# Invalidate specific cache entry
cache_invalidate() {
    local key="$1"
    rm -f "$MLENV_CACHE_DIR/${key}.cache" 2>/dev/null || true
    vlog "Cache invalidated: $key"
}

# Clear all cache
cache_clear_all() {
    rm -rf "$MLENV_CACHE_DIR"/*.cache 2>/dev/null || true
    info "Cache cleared"
}

# Get cache size
cache_size() {
    local count=$(find "$MLENV_CACHE_DIR" -name "*.cache" 2>/dev/null | wc -l)
    echo "$count"
}

# Cache container status
cache_container_status() {
    local container_name="$1"
    local status="$2"
    
    cache_set "container-status-${container_name}" "$status"
}

# Get cached container status
cache_get_container_status() {
    local container_name="$1"
    
    cache_get "container-status-${container_name}"
}

# Invalidate container cache (call after up/down/rm)
cache_invalidate_container() {
    local container_name="$1"
    
    cache_invalidate "container-status-${container_name}"
}

# Cache Docker info
cache_docker_info() {
    local info="$1"
    
    cache_set "docker-info" "$info"
}

# Get cached Docker info
cache_get_docker_info() {
    cache_get "docker-info"
}

# Print cache statistics
cache_stats() {
    cache_init
    
    local total_entries=$(cache_size)
    local cache_dir_size=$(du -sh "$MLENV_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
    
    echo "Cache Statistics:"
    echo "  Directory: $MLENV_CACHE_DIR"
    echo "  Entries:   $total_entries"
    echo "  Size:      $cache_dir_size"
    echo "  TTL:       ${MLENV_CACHE_TTL}s"
}
