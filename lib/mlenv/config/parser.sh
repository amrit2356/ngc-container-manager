#!/usr/bin/env bash
# MLEnv Configuration Parser
# Version: 2.0.0
# Format: INI with sections

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# Global configuration storage
declare -gA MLENV_CONFIG

# Known valid config sections
declare -a VALID_CONFIG_SECTIONS=(
    "core" "container" "gpu" "network" "storage" 
    "resources" "registry" "requirements" "devcontainer" "features"
)

# Validate config key format
config_validate_key() {
    local key="$1"
    
    # Key should be in format: section.key
    if ! [[ "$key" =~ ^[a-z_]+\.[a-z_]+$ ]]; then
        return 1
    fi
    
    # Extract section
    local section="${key%%.*}"
    
    # Check if section is known (warning only, not fatal)
    local valid=false
    for valid_section in "${VALID_CONFIG_SECTIONS[@]}"; do
        if [[ "$section" == "$valid_section" ]]; then
            valid=true
            break
        fi
    done
    
    if [[ "$valid" == "false" ]]; then
        vlog "Unknown config section: $section (this may be intentional)"
    fi
    
    return 0
}

# Parse INI config file
config_parse_file() {
    local config_file="$1"
    local section=""
    
    if [[ ! -f "$config_file" ]]; then
        vlog "Config file not found: $config_file"
        return 1
    fi
    
    vlog "Parsing config file: $config_file"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*\; ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Section header [section]
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            vlog "  Section: [$section]"
            continue
        fi
        
        # Key-value pair
        if [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            # Store with section prefix
            if [[ -n "$section" ]]; then
                local full_key="${section}.${key}"
                # Validate key format
                if ! config_validate_key "$full_key"; then
                    warn "Invalid config key in $config_file: $full_key (skipping)"
                    continue
                fi
                MLENV_CONFIG["$full_key"]="$value"
                vlog "    $full_key = $value"
            else
                # Validate key format
                if ! config_validate_key "$key"; then
                    warn "Invalid config key in $config_file: $key (skipping)"
                    continue
                fi
                MLENV_CONFIG["$key"]="$value"
                vlog "    $key = $value"
            fi
        fi
    done < "$config_file"
    
    return 0
}

# Load configuration hierarchy
config_load_hierarchy() {
    local config_count=0
    
    vlog "Loading configuration hierarchy..."
    
    # 1. System defaults
    if [[ -f "/etc/mlenv/mlenv.conf" ]]; then
        if config_parse_file "/etc/mlenv/mlenv.conf"; then
            vlog "  ✓ System config loaded"
            (( config_count++ )) || true
        fi
    fi
    
    # 2. User config
    if [[ -f "$HOME/.mlenvrc" ]]; then
        if config_parse_file "$HOME/.mlenvrc"; then
            vlog "  ✓ User config loaded"
            (( config_count++ )) || true
        fi
    fi
    
    # 3. Project config
    if [[ -f ".mlenv/config" ]]; then
        if config_parse_file ".mlenv/config"; then
            vlog "  ✓ Project config loaded"
            (( config_count++ )) || true
        fi
    fi
    
    # 4. Environment variable overrides
    config_apply_env_overrides
    
    vlog "Loaded $config_count configuration file(s)"
    return 0
}

# Apply environment variable overrides
config_apply_env_overrides() {
    # Map environment variables to config keys
    local env_mappings=(
        "MLENV_LOG_LEVEL:core.log_level"
        "MLENV_DEFAULT_IMAGE:container.default_image"
        "MLENV_GPU_DEVICES:gpu.default_devices"
        "MLENV_PORTS:network.default_ports"
    )
    
    for mapping in "${env_mappings[@]}"; do
        IFS=':' read -r env_var config_key <<< "$mapping"
        if [[ -n "${!env_var:-}" ]]; then
            MLENV_CONFIG["$config_key"]="${!env_var}"
            vlog "  Env override: $config_key = ${!env_var}"
        fi
    done
}

# Get config value with default
config_get() {
    local key="$1"
    local default="${2:-}"
    
    echo "${MLENV_CONFIG[$key]:-$default}"
}

# Set config value
config_set() {
    local key="$1"
    local value="$2"
    
    MLENV_CONFIG["$key"]="$value"
    vlog "Config set: $key = $value"
}

# Check if config key exists
config_has() {
    local key="$1"
    [[ -n "${MLENV_CONFIG[$key]}" ]]
}

# Delete config key
config_unset() {
    local key="$1"
    unset 'MLENV_CONFIG[$key]'
}

# Get all keys matching pattern
config_keys() {
    local pattern="${1:-}"
    
    if [[ -z "$pattern" ]]; then
        echo "${!MLENV_CONFIG[@]}"
    else
        for key in "${!MLENV_CONFIG[@]}"; do
            if [[ "$key" == $pattern ]]; then
                echo "$key"
            fi
        done
    fi
}

# Show current configuration
config_show() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MLEnv Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local current_section=""
    local keys=($(for key in "${!MLENV_CONFIG[@]}"; do echo "$key"; done | sort))
    
    for key in "${keys[@]}"; do
        # Extract section
        if [[ "$key" =~ ^([^.]+)\.(.+)$ ]]; then
            local section="${BASH_REMATCH[1]}"
            local subkey="${BASH_REMATCH[2]}"
            
            if [[ "$section" != "$current_section" ]]; then
                echo ""
                echo "[$section]"
                current_section="$section"
            fi
            
            printf "  %-30s = %s\n" "$subkey" "${MLENV_CONFIG[$key]}"
        else
            # No section
            printf "%-32s = %s\n" "$key" "${MLENV_CONFIG[$key]}"
        fi
    done
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Save config to file
config_save() {
    local output_file="$1"
    local dir="$(dirname "$output_file")"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            error "Cannot create directory: $dir"
            return 1
        }
    fi
    
    {
        echo "# MLEnv Configuration"
        echo "# Generated: $(date)"
        echo ""
        
        local current_section=""
        local keys=($(for key in "${!MLENV_CONFIG[@]}"; do echo "$key"; done | sort))
        
        for key in "${keys[@]}"; do
            if [[ "$key" =~ ^([^.]+)\.(.+)$ ]]; then
                local section="${BASH_REMATCH[1]}"
                local subkey="${BASH_REMATCH[2]}"
                
                if [[ "$section" != "$current_section" ]]; then
                    echo ""
                    echo "[$section]"
                    current_section="$section"
                fi
                
                echo "$subkey = ${MLENV_CONFIG[$key]}"
            else
                echo "$key = ${MLENV_CONFIG[$key]}"
            fi
        done
    } > "$output_file"
    
    success "Configuration saved to: $output_file"
}

# Initialize config system
config_init() {
    vlog "Initializing configuration system..."
    
    # Set up default log location if not set
    if [[ -z "$MLENV_LOG_FILE" ]]; then
        MLENV_LOG_DIR="${WORKDIR:-.}/.mlenv"
        MLENV_LOG_FILE="$MLENV_LOG_DIR/mlenv.log"
        mkdir -p "$MLENV_LOG_DIR" 2>/dev/null || true
    fi
    
    # Load configuration hierarchy
    config_load_hierarchy
    
    vlog "Configuration system initialized"
}
