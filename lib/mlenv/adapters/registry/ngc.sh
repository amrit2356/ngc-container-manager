#!/usr/bin/env bash
# NGC Registry Adapter
# Version: 2.0.0
# Implements: IAuthManager interface

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# NGC Configuration
NGC_REGISTRY="${MLENV_NGC_REGISTRY:-nvcr.io}"
NGC_CONFIG_DIR="${MLENV_NGC_CONFIG_DIR:-$HOME/.mlenv}"
NGC_CONFIG_FILE="${NGC_CONFIG_DIR}/config"

# Adapter metadata
export NGC_ADAPTER_VERSION="2.0.0"
export NGC_ADAPTER_NAME="ngc"

# Login to NGC registry
ngc_auth_registry_login() {
    local api_key="$1"
    local registry="${2:-$NGC_REGISTRY}"
    
    vlog "[NGC] Logging into $registry..."
    
    # Validate API key
    if [[ -z "$api_key" ]]; then
        # Prompt for API key if not provided
        log "▶ NGC Authentication Setup"
        echo ""
        info "NVIDIA NGC allows you to access private container images"
        info "Get your API key from: https://ngc.nvidia.com/setup/api-key"
        echo ""
        
        read -p "Enter your NGC API Key: " -s api_key
        echo ""
        
        if [[ -z "$api_key" ]]; then
            die "API key cannot be empty"
        fi
    fi
    
    # Login to Docker registry using NGC credentials
    if echo "$api_key" | docker login "$registry" --username '$oauthtoken' --password-stdin >> "${MLENV_LOG_FILE:-/dev/null}" 2>&1; then
        success "Successfully logged into $registry"
        
        # Save credentials
        ngc_save_credentials "$api_key" "$registry"
        
        return 0
    else
        die "Login failed. Please check your API key and try again."
    fi
}

# Logout from NGC registry
ngc_auth_registry_logout() {
    local registry="${1:-$NGC_REGISTRY}"
    
    vlog "[NGC] Logging out of $registry..."
    
    # Logout from Docker registry
    if docker logout "$registry" >> "${MLENV_LOG_FILE:-/dev/null}" 2>&1; then
        success "Logged out of $registry"
    fi
    
    # Remove saved credentials
    if [[ -f "$NGC_CONFIG_FILE" ]]; then
        rm -f "$NGC_CONFIG_FILE"
        success "Removed NGC credentials"
    fi
    
    info "You'll need to run 'mlenv login' again to access private images"
}

# Check if authenticated with NGC
ngc_auth_registry_is_authenticated() {
    local registry="${1:-$NGC_REGISTRY}"
    
    # Check if Docker is logged into the registry
    if docker info 2>/dev/null | grep -q "Username.*${registry}" || \
       grep -q "$registry" ~/.docker/config.json 2>/dev/null; then
        return 0
    fi
    
    # Also check our config file
    if [[ -f "$NGC_CONFIG_FILE" ]]; then
        return 0
    fi
    
    return 1
}

# Get stored credentials
ngc_auth_registry_get_credentials() {
    local registry="${1:-$NGC_REGISTRY}"
    
    if [[ -f "$NGC_CONFIG_FILE" ]]; then
        grep "^apikey" "$NGC_CONFIG_FILE" | cut -d= -f2 | xargs
    fi
}

# Save NGC credentials
ngc_save_credentials() {
    local api_key="$1"
    local registry="${2:-$NGC_REGISTRY}"
    
    mkdir -p "$NGC_CONFIG_DIR"
    chmod 700 "$NGC_CONFIG_DIR"
    
    cat > "$NGC_CONFIG_FILE" <<EOF
; NVIDIA NGC CLI Configuration
; MLEnv v2.0.0
[CURRENT]
apikey = $api_key
registry = $registry
format_type = ascii
org = 

EOF
    chmod 600 "$NGC_CONFIG_FILE"
    vlog "[NGC] Credentials saved to $NGC_CONFIG_FILE"
}

# Check if image requires NGC authentication
ngc_check_auth_required() {
    local image="$1"
    
    # Check if it's an NGC image
    if [[ "$image" != *"nvcr.io"* ]]; then
        return 1  # Not an NGC image
    fi
    
    # Check if it's a private NGC image (not in /nvidia/ org)
    if [[ "$image" == *"/nvidia/"* ]]; then
        return 1  # Public NVIDIA image, no auth needed
    fi
    
    # Private NGC image - check if authenticated
    if ! ngc_auth_registry_is_authenticated; then
        error "Private NGC image requires authentication"
        info "Run: mlenv login"
        return 0  # Auth required
    fi
    
    return 1  # Authenticated
}

# Validate API key format
ngc_validate_api_key() {
    local api_key="$1"
    
    # NGC API keys are long alphanumeric strings with dashes
    if [[ -z "$api_key" ]]; then
        return 1
    fi
    
    # Should be at least 20 characters
    if [[ ${#api_key} -lt 20 ]]; then
        return 1
    fi
    
    return 0
}

# Initialize NGC adapter
ngc_adapter_init() {
    vlog "[NGC] Initializing NGC adapter v${NGC_ADAPTER_VERSION}"
    vlog "[NGC] Registry: $NGC_REGISTRY"
    
    # Create config directory if it doesn't exist
    if [[ ! -d "$NGC_CONFIG_DIR" ]]; then
        mkdir -p "$NGC_CONFIG_DIR"
        chmod 700 "$NGC_CONFIG_DIR"
    fi
    
    vlog "NGC adapter initialized"
}
