# Changelog

All notable changes to MLEnv - ML Environment Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-XX

### Added

#### Architecture & Infrastructure
- **Hexagonal Architecture** - Complete refactor with Ports & Adapters pattern
  - Modular codebase with 70+ organized files
  - Separation of concerns: core logic, adapters, ports, utilities
  - 100% backward compatible with v1.x commands
- **SQLite Backend** - Persistent state management
  - 9 database tables + 2 views for comprehensive tracking
  - Container lifecycle tracking
  - Historical metrics storage
  - Database initialization and migration support
- **Professional Testing Framework**
  - 25+ automated tests (unit, integration, E2E)
  - Test framework with assertions library
  - CI/CD integration with GitHub Actions
  - 100% test pass rate

#### Safety & Monitoring
- **🛡️ Admission Control** - System crash prevention
  - Pre-flight resource checks before container creation
  - Memory threshold: 85% max usage
  - CPU threshold: 90% max usage
  - Minimum available memory: 4GB required
  - Load average validation
  - GPU availability verification
- **📊 Resource Monitoring** - Real-time and historical tracking
  - CPU utilization monitoring
  - Memory usage tracking
  - GPU utilization and memory monitoring
  - Historical metrics storage
  - Project-level resource quotas
- **🏥 Health Checks** - Container wellness monitoring
  - Automatic container health tracking
  - Status reporting and alerts
  - Container lifecycle management

#### Intelligence & Automation
- **🤖 Auto GPU Detection** - Smart GPU allocation
  - `mlenv up --auto-gpu` intelligently selects free GPUs
  - Best GPU selection algorithm
  - Multi-GPU support
  - GPU status display with `mlenv gpu status`
- **🎨 Project Templates** - Quick-start project scaffolding
  - `mlenv init --template pytorch` - Complete PyTorch deep learning setup
  - `mlenv init --template minimal` - Basic project structure
  - Template validation and customization
  - Template engine with YAML configuration
- **🐳 NGC Catalog** - Container image management
  - `mlenv catalog search` - Search NVIDIA NGC catalog
  - `mlenv catalog add` - Add images to favorites
  - `mlenv catalog list` - Browse managed images
  - Catalog persistence in SQLite database

#### Configuration & Developer Experience
- **⚙️ Config File Support** - Persistent defaults
  - Global config: `~/.mlenvrc`
  - Project-level config: `.mlenvrc` in project directory
  - System-wide config: `/etc/mlenv/mlenv.conf`
  - 4-level configuration hierarchy with validation
- **Enhanced Commands**
  - Improved `mlenv list` - Shows all containers across projects
  - Enhanced `mlenv clean` - Interactive cleanup with options
  - Better `mlenv status` - Resource usage display
  - `mlenv init` - Project initialization with templates
  - `mlenv catalog` - NGC image management

#### Enterprise Features
- **📦 Linux Packages** - Production-ready distribution
  - Debian package (`.deb`) with full lifecycle hooks
  - RPM package (`.spec`) for RHEL/CentOS/Fedora
  - Professional build scripts
  - Package installation and uninstallation support
- **Professional Installer**
  - Prerequisite checking (Docker, SQLite, NVIDIA Container Toolkit)
  - Database initialization
  - Shell completion installation (bash/zsh/fish)
  - Uninstaller support
  - Custom installation directory support
- **CI/CD Integration**
  - GitHub Actions workflows for testing
  - Automated release workflows
  - Documentation generation pipeline
- **Comprehensive Documentation**
  - 10+ documentation guides
  - Getting Started guide
  - Deployment guide
  - Migration guide from v1.x
  - Architecture documentation
  - API and CLI reference
  - Development guides

### Changed
- **Complete codebase refactor** - From monolithic script to modular architecture
- **Configuration system** - From no config to 4-level hierarchy
- **Container naming** - Enhanced with better collision prevention
- **Error handling** - Professional error messages with context
- **Logging system** - Structured logging with levels
- **README structure** - Streamlined landing page pointing to comprehensive docs

### Fixed
- All v1.x bugs addressed in refactor
- Improved error messages with actionable suggestions
- Better handling of edge cases in GPU detection
- Enhanced port conflict resolution

### Removed
- Monolithic script structure (replaced with modular architecture)
- Manual configuration (replaced with config file system)

### Documentation
- Complete documentation overhaul
- New documentation site structure (`docs/`)
- Architecture documentation
- Development guides
- Testing documentation
- Deployment guides
- Migration guide from v1.x

### Known Limitations
- No automatic update mechanism (planned for v2.1)
- No web dashboard (planned for v2.1)
- Limited template selection (more templates planned)
- No remote development server (planned for v2.1)

## [1.1.0] - 2025-01-07

### Added
- **VS Code Dev Containers Integration** 🚀
  - Auto-generates `.devcontainer/devcontainer.json` on container creation
  - Container labels for VS Code Dev Containers recognition
  - Automatic workspace folder configuration (`/workspace`)
  - Pre-configured VS Code extensions (Python, Jupyter, Pylance, Debugpy, Ruff)
  - Optimized settings for ML development
  - Port forwarding configuration (Jupyter Lab, TensorBoard)
  - Seamless IDE integration with IntelliSense for container packages

- **Smart Jupyter Command**
  - `mlenv jupyter` now auto-creates containers if they don't exist
  - Automatically sets up port forwarding (default: `8888:8888`)
  - Auto-detects and uses `requirements.txt` if present
  - Auto-recreates containers with proper port forwarding if needed
  - No longer requires running `mlenv up` first

- **Intelligent Port Management**
  - Auto-detects forwarded ports with priority (8888 → 8889-8899 → first available)
  - Automatic container recreation when port forwarding is missing
  - Better error messages with fix suggestions
  - Seamless port detection for Jupyter Lab

### Fixed
- Fixed `get_forwarded_ports()` jq filter bug that prevented port detection
  - Corrected variable scoping in jq query
  - Now properly captures container port when iterating through values

### Changed
- `.devcontainer/` directory now auto-generated and gitignored
- Devcontainer config stored in both `.devcontainer/` (for VS Code) and `.mlenv/` (backup)
- Updated `.gitignore` to include auto-generated Dev Container files
- Enhanced `mlenv jupyter` to be a fully autonomous command

### Documentation
- Added comprehensive VS Code Integration section to README
- Updated Quick Start guide with VS Code workflow
- Added VS Code troubleshooting guide
- Updated project structure examples
- Enhanced security best practices section
- Reorganized roadmap (moved VS Code integration from v2.0 to completed in v1.1.0)

## [1.0.0] - 2025-01-01

### Added
- Initial production release
- **NGC Authentication** - `mlenv login` and `mlenv logout` commands
  - Support for private NGC container images
  - Secure credential storage in `~/.mlenv/config`
  - Automatic authentication check before pulling private images
  - Docker registry login to `nvcr.io`
- `mlenv version` command to show version information
- `mlenv list` command to show all NGC containers across projects
- Enhanced `mlenv clean` command with options:
  - `--logs` - Clean log files (default)
  - `--containers` - Remove stopped NGC containers
  - `--images` - Remove dangling Docker images
  - `--all` - Clean everything
- Professional installer script with:
  - Docker and NVIDIA prerequisites checking
  - System-wide or user-local installation
  - Automatic shell completion installation (bash/zsh/fish)
  - GPU access testing
  - Uninstaller support
- Installation test suite (`test-install.sh`)
- Comprehensive documentation:
  - README.md - Complete project documentation
  - INSTALL.md - Installation guide
  - QUICKSTART.md - Quick reference
  - IMPROVEMENTS.md - Feature comparison
  - PACKAGE_SUMMARY.md - Package overview
  - CHANGELOG.md - Version history

### Core Features
- Smart requirements caching (hash-based)
- Port forwarding support
- GPU device selection
- User mapping (run as current user, not root)
- Environment file support
- Resource limits (CPU, memory)
- Container auto-restart on boot
- Unique container naming (prevents collisions)
- Execute commands without entering container
- One-command Jupyter Lab launch
- Enhanced status with GPU info
- Detailed logging with debug mode

### Commands
- `mlenv up` - Create/start container with extensive options
- `mlenv exec` - Interactive shell or execute command with `-c`
- `mlenv down` - Stop container
- `mlenv restart` - Quick restart
- `mlenv rm` - Remove container
- `mlenv status` - Container and GPU status
- `mlenv list` - List all NGC containers
- `mlenv jupyter` - Launch Jupyter Lab
- `mlenv logs` - View debug logs
- `mlenv clean` - Remove artifacts with options
- `mlenv version` - Show version info
- `mlenv help` - Comprehensive help

### Documentation
- 6 real-world examples (PyTorch, Jupyter, DDP, serving, data processing, TensorFlow)
- Architecture diagrams
- Troubleshooting guide
- Security best practices
- Performance tips
- Multi-user setup guide
- CI/CD integration examples

### Known Limitations
- No automatic update mechanism (manual git pull required)
- No persistent config file support (`.ngcrc` planned for v1.2)
- Shell completions require terminal restart to activate
- No built-in experiment tracking integration
- No VS Code devcontainer generation
- Not supported on macOS (Linux only, or WSL2 on Windows)

## [Unreleased]

### Planned for v2.1
- [ ] Web Dashboard - Monitor containers and GPUs via web UI
- [ ] More Templates - TensorFlow, Transformers, Stable Diffusion
- [ ] Remote Development - SSH server for remote access
- [ ] Enhanced Monitoring - Real-time graphs and alerts

### Planned for v2.2
- [ ] Experiment Tracking - Built-in W&B, MLflow integration
- [ ] Multi-container - Docker Compose-style orchestration
- [ ] GPU Scheduling - Queue and wait for GPU availability
- [ ] Jupyter Extensions - Auto-install popular extensions

### Planned for v3.0
- [ ] Cloud Integration - Deploy to AWS, GCP, Azure
- [ ] Team Features - Shared resource pools, user quotas
- [ ] Container Snapshots - Save/restore container state
- [ ] Central Management - Multi-server dashboard

## Contributing

See [README.md](README.md#contributing) for contribution guidelines.

## Support

- Issues: [GitHub Issues](https://github.com/amrit2356/mlenv/issues)
- Discussions: [GitHub Discussions](https://github.com/amrit2356/mlenv/discussions)