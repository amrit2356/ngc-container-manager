#!/usr/bin/env bash
# MLEnv Sync Command
# Version: 2.1.0
# Synchronizes database state with Docker reality

cmd_sync() {
    # Source sync utilities
    source "${MLENV_LIB}/database/sync.sh"
    
    # Parse options
    local quick_check=false
    local containers_only=false
    local gpus_only=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check|-c)
                quick_check=true
                shift
                ;;
            --containers)
                containers_only=true
                shift
                ;;
            --gpus)
                gpus_only=true
                shift
                ;;
            --help|-h)
                echo "Usage: mlenv sync [OPTIONS]"
                echo ""
                echo "Synchronize database state with Docker reality"
                echo ""
                echo "Options:"
                echo "  -c, --check        Quick check only (no fixes)"
                echo "  --containers       Sync containers only"
                echo "  --gpus             Sync GPU allocations only"
                echo "  -h, --help         Show this help"
                return 0
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Quick check mode
    if [[ "$quick_check" == "true" ]]; then
        if sync_quick_check; then
            success "System state is synchronized"
            return 0
        else
            warn "State discrepancies detected"
            info "Run 'mlenv sync' to fix them"
            return 1
        fi
    fi
    
    # Selective sync
    if [[ "$containers_only" == "true" ]]; then
        sync_all_containers
        return $?
    fi
    
    if [[ "$gpus_only" == "true" ]]; then
        sync_gpu_allocations
        return $?
    fi
    
    # Full sync
    sync_full_system
}
