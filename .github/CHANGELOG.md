# Changelog

All notable changes to MLEnv - ML Environment Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Planned for v1.2
- [ ] Automatic update checker and updater
- [ ] Container resource usage in status
- [ ] Improved error messages with suggestions
- [ ] Full integration test suite

### Planned for v1.3
- [ ] Config file support (`~/.ngcrc`)
- [ ] Project templates
- [ ] Auto GPU detection
- [ ] SSH server for remote development

### Planned for v2.0
- [ ] Multi-container support (docker-compose style)
- [ ] Experiment tracking integration (W&B, MLflow)
- [ ] GPU scheduling (wait for availability)
- [ ] Jupyter extensions auto-install
- [ ] Team dashboard for shared servers
- [ ] Cloud integration (AWS, GCP, Azure)

## Contributing

See [README.md](README.md#contributing) for contribution guidelines.

## Support

- Issues: [GitHub Issues](https://github.com/your-username/mlenv/issues)
- Discussions: [GitHub Discussions](https://github.com/your-username/mlenv/discussions)