#!/usr/bin/env bash
# MLEnv Config Command
# Version: 2.1.0 - Context-based

cmd_config() {
    local subcmd="${1:-show}"
    shift || true
    
    case "$subcmd" in
        show)
            config_show || {
                error_with_help "Failed to show configuration" "config_error"
                return 1
            }
            ;;
        get)
            local key="$1"
            if [[ -z "$key" ]]; then
                error_with_help "Config key required" "invalid_argument"
                info "Usage: mlenv config get <key>"
                return 1
            fi
            config_get "$key" || {
                error_with_help "Config key not found: $key" "config_error"
                return 1
            }
            ;;
        set)
            local key="$1"
            local value="$2"
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                error_with_help "Config key and value required" "invalid_argument"
                info "Usage: mlenv config set <key> <value>"
                return 1
            fi
            config_set "$key" "$value" || {
                error_with_help "Failed to set config" "config_error"
                return 1
            }
            success "Set $key = $value"
            ;;
        generate)
            local output="${1:-$HOME/.mlenvrc}"
            config_save "$output" || {
                error_with_help "Failed to generate config file" "config_error"
                return 1
            }
            success "Generated config: $output"
            ;;
        *)
            echo "Usage: mlenv config {show|get|set|generate}"
            echo ""
            echo "Commands:"
            echo "  show              Show current configuration"
            echo "  get <key>         Get specific config value"
            echo "  set <key> <val>   Set config value"
            echo "  generate [path]   Generate config file (default: ~/.mlenvrc)"
            return 1
            ;;
    esac
    
    return 0
}
