#!/usr/bin/env bash
# MLEnv Clean Command
# Version: 2.1.0 - Context-based
# Removes MLEnv artifacts, logs, and optionally containers/images

# Source command helpers
source "${MLENV_LIB}/utils/command-helpers.sh"

cmd_clean() {
  # Initialize context
  declare -A ctx
  cmd_init_context ctx || return 1
  
  local log_dir="${ctx[log_dir]}"
  local workdir="${ctx[workdir]}"
  
  local clean_logs=false
  local clean_containers=false
  local clean_images=false
  
  # Parse clean options
  if [ $# -eq 0 ]; then
    # Default: just logs
    clean_logs=true
  else
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --logs)
          clean_logs=true
          shift
          ;;
        --containers)
          clean_containers=true
          shift
          ;;
        --images)
          clean_images=true
          shift
          ;;
        --all)
          clean_logs=true
          clean_containers=true
          clean_images=true
          shift
          ;;
        *)
          warn "Unknown option: $1"
          shift
          ;;
      esac
    done
  fi
  
  log "▶ Cleaning MLEnv artifacts"
  echo ""
  
  # Clean logs
  if [ "$clean_logs" = true ]; then
    if [ -d "$log_dir" ]; then
      rm -rf "$log_dir" || {
        error_with_help "Failed to clean logs: $log_dir" "permission_denied"
        return 1
      }
      success "Cleaned logs: $log_dir"
    else
      info "No logs to clean"
    fi
  fi
  
  # Clean old containers
  if [ "$clean_containers" = true ]; then
    echo ""
    info "Searching for stopped MLEnv containers..."
    local stopped_containers
    stopped_containers=$(docker ps -a --filter "name=mlenv-" --filter "status=exited" --format "{{.Names}}" 2>/dev/null || true)
    
    if [ -n "$stopped_containers" ]; then
      echo ""
      echo "Stopped containers found:"
      echo "$stopped_containers" | while read -r container; do
        echo "  - $container"
      done
      echo ""
      read -p "Remove these containers? [y/N] " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$stopped_containers" | while read -r container; do
          docker rm "$container" >/dev/null 2>&1
          success "Removed: $container"
        done
      else
        info "Skipped container cleanup"
      fi
    else
      info "No stopped MLEnv containers found"
    fi
  fi
  
  # Clean dangling images
  if [ "$clean_images" = true ]; then
    echo ""
    read -p "Remove dangling Docker images? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      docker image prune -f
      success "Cleaned dangling images"
    else
      info "Skipped image cleanup"
    fi
  fi
  
  echo ""
  success "Cleanup complete"
  return 0
}
