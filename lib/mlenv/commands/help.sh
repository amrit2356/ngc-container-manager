#!/usr/bin/env bash
# MLEnv Help Command
# Version: 2.1.0 - Context-based

# Source command helpers
source "${MLENV_LIB}/utils/command-helpers.sh"

cmd_help() {
    # Initialize context
    declare -A ctx
    cmd_init_context ctx || return 1
    
    local version="${ctx[version]}"
    
    cat <<EOF
MLEnv - ML Environment Manager v${version}

USAGE:
  mlenv <command> [options]

COMMANDS:
  login       Authenticate with NGC
  logout      Remove NGC authentication
  catalog     Browse and manage NGC image catalog
  init        Initialize project from template
  up          Create/start container
  exec        Open interactive shell (or run command with -c)
  down        Stop container
  restart     Restart container
  rm          Remove container (keeps your code safe)
  status      Show container status
  jupyter     Start Jupyter Lab (auto-detects ports)
  logs        View debug logs
  clean       Remove MLEnv artifacts and optionally containers/images
  config      Manage configuration
  version     Show version information
  help        Show this help

CLEAN COMMANDS:
  mlenv clean                  Clean logs (default)
  mlenv clean --logs           Clean logs only
  mlenv clean --containers     Remove stopped MLEnv containers
  mlenv clean --images         Remove dangling Docker images
  mlenv clean --all            Clean everything (logs, containers, images)

CONFIG COMMANDS:
  mlenv config show            Show current configuration
  mlenv config get <key>       Get config value
  mlenv config set <key> <val> Set config value
  mlenv config generate        Generate ~/.mlenvrc

CATALOG COMMANDS:
  mlenv catalog list           List popular NGC images by category
  mlenv catalog search <query> Search for NGC images
  mlenv catalog stats          Show catalog statistics
  mlenv catalog add <org> <name>      Add custom image
  mlenv catalog remove <org> <name>   Remove image

INIT COMMANDS:
  mlenv init --list                      List available templates
  mlenv init --template <name> [dir]     Create project from template
  
  Examples:
    mlenv init --list
    mlenv init --template pytorch my-project
    mlenv init --template minimal my-experiment

OPTIONS (for 'up' command):
  --image <name>              Docker image
  --requirements <path>       Install Python requirements from file
  --force-requirements        Force reinstall requirements
  --port <mapping>            Port forwarding (e.g., "8888:8888,6006:6006")
  --gpu <devices>             GPU devices (e.g., "0,1" or "all")
  --env-file <path>           Environment variables file
  --memory <limit>            Memory limit (e.g., "16g")
  --cpus <limit>              CPU limit (e.g., "4.0")
  --no-user-mapping           Run as root instead of current user
  --verbose                   Enable verbose output

EXAMPLES:
  # Basic setup
  mlenv up
  mlenv exec

  # With configuration file
  cp $(dirname $(which mlenv))/../share/mlenv/examples/mlenvrc.example ~/.mlenvrc
  # Edit ~/.mlenvrc with your preferences
  mlenv up

  # Full setup with Jupyter
  mlenv up --requirements requirements.txt --port 8888:8888,6006:6006
  
For more information: https://github.com/your-username/mlenv
EOF
    return 0
}
