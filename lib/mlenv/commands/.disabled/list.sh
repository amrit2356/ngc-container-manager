#!/usr/bin/env bash
# MLEnv List Command
# Version: 2.0.0

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"

# List all MLEnv containers
cmd_list() {
    info "MLEnv Containers Across All Projects"
    echo ""
    
    local containers
    containers=$(docker ps -a --filter "name=mlenv-" --format "{{.Names}}" 2>/dev/null || true)
    
    if [[ -z "$containers" ]]; then
        info "No MLEnv containers found"
        return 0
    fi
    
    # Header
    printf "%-40s %-15s %-20s\n" "CONTAINER" "STATUS" "IMAGE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # List containers
    docker ps -a --filter "name=mlenv-" --format "{{.Names}}\t{{.Status}}\t{{.Image}}" | \
        while IFS=$'\t' read -r name status image; do
        # Truncate long names/images
        name_short="${name:0:39}"
        image_short="${image:0:19}"
        status_short="${status:0:14}"
        
        printf "%-40s %-15s %-20s\n" "$name_short" "$status_short" "$image_short"
    done
    
    echo ""
    local total
    total=$(echo "$containers" | wc -l)
    info "Total: $total containers"
    echo ""
    info "Tip: Use 'mlenv clean --containers' to remove stopped containers"
}
