#!/usr/bin/env bash
# MLEnv Config Command
# Version: 2.0.0

cmd_config() {
    local subcmd="${1:-show}"
    shift || true
    
    case "$subcmd" in
        show)
            config_show
            ;;
        get)
            local key="$1"
            config_get "$key"
            ;;
        set)
            local key="$1"
            local value="$2"
            config_set "$key" "$value"
            success "Set $key = $value"
            ;;
        generate)
            local output="${1:-$HOME/.mlenvrc}"
            config_save "$output"
            ;;
        *)
            echo "Usage: mlenv config {show|get|set|generate}"
            ;;
    esac
}
