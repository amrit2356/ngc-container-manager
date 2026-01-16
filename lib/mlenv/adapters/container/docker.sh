#!/usr/bin/env bash
# Docker Container Adapter
# Version: 2.0.0
# Implements: IContainerManager interface

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"

# Adapter metadata
export DOCKER_ADAPTER_VERSION="2.0.0"
export DOCKER_ADAPTER_NAME="docker"

# Create container
docker_container_create() {
    local name="$1"
    shift
    local args=("$@")
    
    vlog "[Docker] Creating container: $name"
    
    if docker run "${args[@]}" 2>&1 | tee -a "${MLENV_LOG_FILE:-/dev/null}"; then
        vlog "[Docker] Container created successfully: $name"
        return 0
    else
        error "[Docker] Failed to create container: $name"
        return 1
    fi
}

# Start container
docker_container_start() {
    local name="$1"
    
    vlog "[Docker] Starting container: $name"
    docker start "$name" >> "${MLENV_LOG_FILE:-/dev/null}" 2>&1
}

# Stop container
docker_container_stop() {
    local name="$1"
    
    vlog "[Docker] Stopping container: $name"
    docker stop "$name" >> "${MLENV_LOG_FILE:-/dev/null}" 2>&1
}

# Remove container
docker_container_remove() {
    local name="$1"
    
    vlog "[Docker] Removing container: $name"
    docker rm -f "$name" >> "${MLENV_LOG_FILE:-/dev/null}" 2>&1
}

# Execute command in container
docker_container_exec() {
    local name="$1"
    shift
    
    # Separate options from command
    # Docker exec format: docker exec [OPTIONS] CONTAINER COMMAND [ARG...]
    local options=()
    local command=()
    local in_command=false
    local expect_option_value=false
    
    # Options that take a value
    local value_options=("-u" "--user" "-e" "--env" "-w" "--workdir")
    
    for arg in "$@"; do
        if [[ "$in_command" == "true" ]]; then
            # Already in command, everything goes to command
            command+=("$arg")
        elif [[ "$expect_option_value" == "true" ]]; then
            # This is a value for the previous option
            options+=("$arg")
            expect_option_value=false
        elif [[ "$arg" =~ ^- ]]; then
            # This is an option
            options+=("$arg")
            # Check if this option expects a value
            for opt in "${value_options[@]}"; do
                if [[ "$arg" == "$opt" ]]; then
                    expect_option_value=true
                    break
                fi
            done
        else
            # Not an option, not expecting an option value -> this is the command
            in_command=true
            command+=("$arg")
        fi
    done
    
    vlog "[Docker] Executing in container: $name"
    docker exec "${options[@]}" "$name" "${command[@]}"
}

# Inspect container
docker_container_inspect() {
    local name="$1"
    
    docker inspect "$name" 2>/dev/null
}

# List containers
docker_container_list() {
    local filter="${1:-}"
    
    if [[ -n "$filter" ]]; then
        docker ps -a --filter "$filter"
    else
        docker ps -a
    fi
}

# Get container logs
docker_container_logs() {
    local name="$1"
    shift
    local args=("$@")
    
    docker logs "${args[@]}" "$name"
}

# Check if container exists
docker_container_exists() {
    local name="$1"
    
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"
}

# Check if container is running
docker_container_is_running() {
    local name="$1"
    
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"
}

# Get forwarded ports
docker_container_get_forwarded_ports() {
    local name="$1"
    
    docker inspect "$name" 2>/dev/null | \
        jq -r '.[0].NetworkSettings.Ports | to_entries[] | select(.value != null) | .key as $port | .value[] | "\(.HostPort):\($port | split("/")[0])"' 2>/dev/null || true
}

# Get container stats
docker_container_stats() {
    local name="$1"
    local no_stream="${2:---no-stream}"
    
    docker stats "$no_stream" "$name" 2>/dev/null
}

# Image operations

# Pull image
docker_image_pull() {
    local image="$1"
    
    vlog "[Docker] Pulling image: $image"
    
    if docker pull "$image" 2>&1 | tee -a "${MLENV_LOG_FILE:-/dev/null}"; then
        vlog "[Docker] Image pulled successfully: $image"
        return 0
    else
        error "[Docker] Failed to pull image: $image"
        return 1
    fi
}

# Push image
docker_image_push() {
    local image="$1"
    
    vlog "[Docker] Pushing image: $image"
    docker push "$image" 2>&1 | tee -a "${MLENV_LOG_FILE:-/dev/null}"
}

# List images
docker_image_list() {
    local filter="${1:-}"
    
    if [[ -n "$filter" ]]; then
        docker images --filter "$filter"
    else
        docker images
    fi
}

# Remove image
docker_image_remove() {
    local image="$1"
    
    vlog "[Docker] Removing image: $image"
    docker rmi "$image" >> "${MLENV_LOG_FILE:-/dev/null}" 2>&1
}

# Inspect image
docker_image_inspect() {
    local image="$1"
    
    docker inspect "$image" 2>/dev/null
}

# Tag image
docker_image_tag() {
    local source="$1"
    local target="$2"
    
    vlog "[Docker] Tagging image: $source -> $target"
    docker tag "$source" "$target"
}

# Check if image exists
docker_image_exists() {
    local image="$1"
    
    docker image inspect "$image" >/dev/null 2>&1
}

# Check Docker prerequisites
docker_check_prerequisites() {
    # Check if Docker command exists
    if ! command -v docker >/dev/null 2>&1; then
        die "Docker is not installed. Install from https://docs.docker.com/get-docker/"
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        die "Docker daemon is not running. Start Docker and try again."
    fi
    
    vlog "[Docker] Prerequisites check passed"
}

# Check GPU support
docker_check_gpu() {
    if ! docker info 2>/dev/null | grep -q "Runtimes:.*nvidia"; then
        die "NVIDIA Container Toolkit not detected. Install from https://github.com/NVIDIA/nvidia-container-toolkit"
    fi
    
    vlog "[Docker] GPU runtime check passed"
}

# Initialize Docker adapter
docker_adapter_init() {
    vlog "[Docker] Initializing Docker adapter v${DOCKER_ADAPTER_VERSION}"
    
    # Run prerequisite checks
    docker_check_prerequisites
    
    # Check GPU support if required
    if [[ "${MLENV_REQUIRE_GPU:-true}" == "true" ]]; then
        docker_check_gpu
    fi
    
    vlog "Docker adapter initialized"
}
