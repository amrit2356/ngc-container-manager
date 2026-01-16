#!/usr/bin/env bash
# MLEnv Port Utilities
# Version: 2.0.0

# Get forwarded ports from container
get_forwarded_ports() {
    local container_name="${1:-$CONTAINER_NAME}"
    container_get_forwarded_ports "$container_name" 2>/dev/null || true
}

# Find Jupyter port from forwarded ports
find_jupyter_port() {
    # Try to find a suitable port for Jupyter from forwarded ports
    # Priority: 8888, then 8889-8899, then first available in forwarded range
    local forwarded_ports
    forwarded_ports=$(get_forwarded_ports)
    
    if [[ -z "$forwarded_ports" ]]; then
        echo ""
        return 1
    fi
    
    # Check for 8888 first
    if echo "$forwarded_ports" | grep -q ":8888$"; then
        echo "8888"
        return 0
    fi
    
    # Check for 8889-8899
    for port in {8889..8899}; do
        if echo "$forwarded_ports" | grep -q ":${port}$"; then
            echo "$port"
            return 0
        fi
    done
    
    # Return first forwarded port in the range
    local first_port
    first_port=$(echo "$forwarded_ports" | grep -E ":[0-9]+$" | head -1 | cut -d: -f2)
    if [[ -n "$first_port" ]]; then
        echo "$first_port"
        return 0
    fi
    
    echo ""
    return 1
}

# Find an available port on the host
find_available_port() {
    # Find an available port on the host, starting from a given port
    # Usage: find_available_port [start_port]
    local start_port="${1:-8888}"
    local max_port=8999
    local port=$start_port
    
    while [[ $port -le $max_port ]]; do
        # Check if port is available (not in use)
        if ! netstat -tuln 2>/dev/null | grep -q ":${port} " && \
           ! ss -tuln 2>/dev/null | grep -q ":${port} "; then
            # Double-check with lsof if available
            if command -v lsof >/dev/null 2>&1; then
                if ! lsof -i ":${port}" >/dev/null 2>&1; then
                    echo "$port"
                    return 0
                fi
            else
                # lsof not available, trust netstat/ss
                echo "$port"
                return 0
            fi
        fi
        port=$((port + 1))
    done
    
    # No available port found
    echo ""
    return 1
}
