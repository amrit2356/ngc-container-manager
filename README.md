# MLEnv - ML Environment Manager

![Version](https://img.shields.io/badge/version-1.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![NVIDIA](https://img.shields.io/badge/NVIDIA-GPU-76B900?logo=nvidia)
![Docker](https://img.shields.io/badge/Docker-20.10+-2496ED?logo=docker&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)
![CUDA](https://img.shields.io/badge/CUDA-Enabled-76B900)
![VS Code](https://img.shields.io/badge/VS%20Code-Dev%20Containers-007ACC?logo=visualstudiocode)

**Production-Ready GPU Container Management**

A production-grade command-line tool for managing NVIDIA GPU-accelerated Docker containers for deep learning and scientific computing. Simplifies the workflow of running PyTorch, TensorFlow, and other GPU workloads while keeping your code safely on the host machine.

## 🚀 Features

- **Zero-Config GPU Access** - Automatic NVIDIA GPU detection and passthrough
- **VS Code Dev Containers** - Auto-generated config for seamless VS Code integration
- **Smart Jupyter** - `mlenv jupyter` auto-creates containers with port forwarding
- **Smart Requirements Management** - Hash-based caching prevents redundant pip installs
- **Persistent Workspaces** - Your code stays on the host (bind-mounted)
- **Port Forwarding** - Easy access to Jupyter, TensorBoard, APIs
- **Resource Controls** - Limit CPU, memory, and GPU usage
- **Multi-Project Support** - Unique container names prevent collisions
- **User Mapping** - Run as your user, not root (no permission issues)
- **One-Line Commands** - `mlenv jupyter`, `mlenv exec -c "train.py"`
- **Auto-Restart** - Containers survive system reboots

## 📋 Prerequisites

- **Docker** (version 20.10+)
- **NVIDIA GPU** with compatible drivers
- **NVIDIA Container Toolkit** ([installation guide](https://github.com/NVIDIA/nvidia-container-toolkit))

Verify your setup:
```bash
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

## 🔧 Installation

### Automatic Installation (Recommended)
```bash
# Clone the repository
git clone https://github.com/your-username/mlenv.git
cd mlenv

# Run installer (checks prerequisites, installs script + completions)
sudo ./install.sh

# Verify installation
mlenv help
```

The installer will:
- ✅ Check Docker and NVIDIA Container Toolkit
- ✅ Install NGC to `/usr/local/bin`
- ✅ Install shell completions (bash/zsh/fish)
- ✅ Test GPU access

### Installation Options
```bash
# Check prerequisites without installing
./install.sh --check

# Install to custom directory (no sudo needed)
./install.sh --install-dir ~/.local/bin

# Force reinstall
sudo ./install.sh --force

# Uninstall
sudo ./install.sh --uninstall
```

### Manual Installation
```bash
# Download and make executable
chmod +x ngc

# Copy to system directory
sudo cp ngc /usr/local/bin/

# Or use without sudo (add to PATH)
mkdir -p ~/.local/bin
cp ngc ~/.local/bin/
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## ⚡ Quick Start

### Basic Usage
```bash
# Start a container
mlenv up

# Enter interactive shell
mlenv exec

# Run your code (inside container)
python train.py

# Exit (Ctrl+D or type 'exit')
# Container keeps running in background

# Stop when done
mlenv down
```

### For Private NGC Images
If you need private container images from NGC:

```bash
# 1. Get API key from https://ngc.nvidia.com/setup/api-key

# 2. Authenticate
mlenv login

# 3. Use private images
mlenv up --image nvcr.io/your-org/your-private-image:latest
```

**Note:** Public images like `nvcr.io/nvidia/pytorch:25.12-py3` don't require authentication.

### With Jupyter Lab
```bash
# Simple - auto-creates container with port forwarding
mlenv jupyter

# Or with manual setup
mlenv up --port 8888:8888
mlenv jupyter

# Open the URL shown in terminal
# http://localhost:8888/...
```

### With VS Code Dev Containers
```bash
# Start container (creates .devcontainer/devcontainer.json automatically)
mlenv up --port 8888:8888

# In VS Code:
# 1. Install "Dev Containers" extension
# 2. Ctrl+Shift+P → "Dev Containers: Open Folder in Container"
# 3. Select your project folder
# 4. VS Code opens in /workspace with GPU access!

# Benefits:
# - Python IntelliSense works with container packages
# - Jupyter notebooks run in container kernel
# - Integrated terminal runs inside container
# - All extensions auto-installed
```

### With Requirements
```bash
# requirements.txt
# torch==2.1.0
# transformers==4.35.0
# jupyter==1.0.0

mlenv up --requirements requirements.txt --port 8888:8888
mlenv exec
```

## 📚 Usage

### Commands

| Command | Description |
|---------|-------------|
| `mlenv up` | Create/start container |
| `mlenv exec` | Open interactive shell |
| `mlenv down` | Stop container |
| `mlenv restart` | Restart container |
| `mlenv rm` | Remove container (keeps code) |
| `mlenv status` | Show container and GPU status |
| `mlenv jupyter` | Start Jupyter Lab (auto-creates container with ports) |
| `mlenv logs` | View debug logs |
| `mlenv clean` | Remove NGC artifacts |
| `mlenv help` | Show detailed help |

### Options for `mlenv up`

```bash
mlenv up [OPTIONS]

Options:
  --image <name>              Docker image (default: nvcr.io/nvidia/pytorch:25.12-py3)
  --requirements <file>       Install Python packages from file
  --force-requirements        Force reinstall even if cached
  --port <mapping>            Port forwarding (e.g., "8888:8888" or "8888:8888,6006:6006")
  --gpu <devices>             GPU devices (e.g., "0,1" or "all", default: all)
  --env-file <file>           Load environment variables from file
  --memory <limit>            Memory limit (e.g., "16g", "32g")
  --cpus <limit>              CPU limit (e.g., "4.0", "8.0")
  --no-user-mapping           Run as root instead of current user
  --verbose                   Enable verbose output
```

### Options for `mlenv exec`

```bash
mlenv exec [-c <command>]

Options:
  -c <command>                Execute command instead of interactive shell

Examples:
  mlenv exec                            # Interactive shell
  mlenv exec -c "python train.py"       # Run training script
  mlenv exec -c "pip list | grep torch" # Check installed packages
```

## 💡 Examples

### Example 1: PyTorch Deep Learning
```bash
# requirements.txt
torch==2.1.0
torchvision==0.16.0
tensorboard==2.15.0
wandb==0.16.0

# .env
WANDB_API_KEY=your_api_key_here
CUDA_VISIBLE_DEVICES=0,1

# Setup environment
mlenv up \
  --requirements requirements.txt \
  --env-file .env \
  --port 6006:6006 \
  --gpu 0,1 \
  --memory 32g

# Start training
mlenv exec -c "python train.py --batch-size 64 --epochs 100"

# Monitor with TensorBoard (in another terminal)
mlenv exec -c "tensorboard --logdir runs --host 0.0.0.0"
# Open: http://localhost:6006
```

### Example 2: Jupyter Notebook Development
```bash
# Start container with Jupyter port
mlenv up --requirements requirements.txt --port 8888:8888

# Launch Jupyter Lab
mlenv jupyter

# Open the provided URL in your browser
# Notebooks saved in /workspace are automatically synced to host
```

### Example 3: Distributed Training (Multi-GPU)
```bash
# Use all available GPUs
mlenv up --requirements requirements.txt --gpu all

# Run distributed training
mlenv exec -c "torchrun --nproc_per_node=4 train_ddp.py --config config.yaml"
```

### Example 4: Model Inference API
```bash
# requirements.txt
fastapi==0.104.0
uvicorn==0.24.0
torch==2.1.0
transformers==4.35.0

# Start with API port
mlenv up --requirements requirements.txt --port 8000:8000 --gpu 0

# Run FastAPI server
mlenv exec -c "uvicorn app:app --host 0.0.0.0 --port 8000"

# API available at http://localhost:8000
```

### Example 5: Data Processing (CPU-Heavy)
```bash
# requirements.txt
pandas==2.1.0
polars==0.19.0
dask==2023.10.0

# High CPU/memory, no GPU needed
mlenv up \
  --requirements requirements.txt \
  --memory 64g \
  --cpus 16.0 \
  --gpu 0  # Use only one GPU or none

# Process large dataset
mlenv exec -c "python process_data.py --input data/raw --output data/processed"
```

### Example 6: Custom Image (TensorFlow)
```bash
# Use TensorFlow image instead of PyTorch
mlenv up \
  --image nvcr.io/nvidia/tensorflow:24.12-tf2-py3 \
  --requirements requirements.txt \
  --port 8888:8888

mlenv exec
```

## 🔐 NGC Authentication

### When Do You Need It?

**Public Images** - No authentication needed:
- `nvcr.io/nvidia/pytorch:*`
- `nvcr.io/nvidia/tensorflow:*`
- `nvcr.io/nvidia/cuda:*`

**Private Images** - Authentication required:
- `nvcr.io/your-org/your-private-model:*`
- Organization-specific images
- Enterprise NGC images

### Setup Authentication

```bash
# 1. Get your NGC API Key
# Visit: https://ngc.nvidia.com/setup/api-key
# Click "Generate API Key"

# 2. Login to NGC
mlenv login
# Paste your API key when prompted

# 3. Verify authentication
docker info | grep nvcr.io
# Should show: Username: $oauthtoken

# 4. Use private images
mlenv up --image nvcr.io/your-org/private-model:latest
```

### What Gets Stored?

```bash
~/.mlenv/config           # NGC API key
~/.docker/config.json   # Docker registry credentials
```

### Logout

```bash
mlenv logout
# Removes NGC credentials and Docker login
```

### Troubleshooting

**"unauthorized: authentication required"**
```bash
# Not logged in, run:
mlenv login
```

**"Error response from daemon: Get https://nvcr.io/v2/: unauthorized"**
```bash
# Expired/invalid API key
mlenv logout
mlenv login  # Enter new key
```

**Check if logged in:**
```bash
cat ~/.mlenv/config
# or
docker info | grep nvcr.io
```

## 🔍 How It Works

### Architecture
```
Host Machine                    Docker Container
┌─────────────────┐            ┌─────────────────┐
│  /your/project  │◄──bind────►│   /workspace    │
│                 │   mount    │                 │
│  ├── train.py   │            │  ├── train.py   │
│  ├── data/      │            │  ├── data/      │
│  └── .mlenv/    │            │  └── (GPUs)     │
└─────────────────┘            └─────────────────┘
        ▲                               │
        └──────────────┬────────────────┘
                       │
                  localhost:8888
```

### Key Concepts

1. **Bind Mounting**: Your project directory is mounted into the container at `/workspace`. Changes are immediately synced both ways.

2. **Container Persistence**: Containers stay running in the background. Stop with `mlenv down`, remove with `mlenv rm`.

3. **Smart Caching**: Requirements are hashed. Reinstalls only happen if the file changes (override with `--force-requirements`).

4. **Unique Naming**: Container names include a directory hash (`ngc-myproject-a3f8c21d`) to prevent collisions across different project directories.

5. **User Mapping**: By default, runs as your user (`uid:gid`) to avoid permission issues with created files.

## 💻 VS Code Integration

MLEnv automatically generates VS Code Dev Container configuration for seamless integration.

### Quick Start with VS Code

```bash
# 1. Start your container
mlenv jupyter  # or: mlenv up --port 8888:8888

# 2. In VS Code, install "Dev Containers" extension

# 3. Attach to container
# Ctrl+Shift+P → "Dev Containers: Open Folder in Container"
# Select your project directory

# VS Code will:
# ✅ Open in /workspace (your project files)
# ✅ Auto-install Python, Jupyter, Pylance extensions
# ✅ Configure Python interpreter from container
# ✅ Enable GPU-accelerated development
```

### What Gets Auto-Configured

When you create a container, MLEnv automatically generates `.devcontainer/devcontainer.json` with:

- **Workspace Folder**: `/workspace` (auto-opens here)
- **Remote User**: `ubuntu` (not root)
- **Extensions**: Python, Jupyter, Pylance, Debugpy, Ruff
- **Port Forwarding**: 8888 (Jupyter Lab), 6006 (TensorBoard)
- **Settings**: Optimized for ML development

### Features You Get

```bash
# IntelliSense with container packages
# Works with transformers, torch, etc. installed in container

# Jupyter notebooks
# Use container's kernel directly in VS Code

# Integrated terminal
# Runs inside container with GPU access

# Debugging
# Debug Python code with container's interpreter

# File sync
# Changes sync automatically between host and container
```

### Manual Connection Setup

If you prefer to connect to an existing Jupyter server:

```bash
# 1. Start Jupyter
mlenv jupyter

# 2. Copy the token URL (e.g., http://127.0.0.1:8888/lab?token=...)

# 3. In VS Code:
# - Open a .ipynb file
# - Click "Select Kernel"
# - Choose "Existing Jupyter Server"
# - Paste the URL (change /lab to /?token=...)
# - Select Python kernel
```

### Troubleshooting VS Code

**Opens in /root instead of /workspace:**
```bash
# Ensure .devcontainer/devcontainer.json exists
ls .devcontainer/devcontainer.json

# If missing, recreate container
mlenv rm
mlenv jupyter  # Auto-generates config
```

**Extensions not installed:**
```bash
# Check devcontainer.json exists
cat .devcontainer/devcontainer.json

# Reload window: Ctrl+Shift+P → "Developer: Reload Window"
```

**Files not syncing:**
```bash
# Verify you're in /workspace
pwd  # Should show: /workspace

# If in wrong directory:
# File → Open Folder → /workspace
```

## 🛠️ Advanced Usage

### Multiple Projects
Each directory gets its own container:
```bash
cd /projects/nlp-research
mlenv up  # Creates: ngc-nlp-research-abc123

cd /projects/computer-vision  
mlenv up  # Creates: ngc-computer-vision-def456

# Both can run simultaneously
```

### Custom Docker Images
```bash
# NVIDIA PyTorch (default)
mlenv up --image nvcr.io/nvidia/pytorch:25.12-py3

# NVIDIA TensorFlow
mlenv up --image nvcr.io/nvidia/tensorflow:24.12-tf2-py3

# Custom image with your base setup
mlenv up --image yourusername/ml-base:latest
```

### Environment Variables
```bash
# .env file
API_KEY=secret123
MODEL_PATH=/workspace/models
BATCH_SIZE=32
WANDB_PROJECT=my-experiment

mlenv up --env-file .env

# Access inside container
mlenv exec -c 'echo $API_KEY'
```

### Resource Management
```bash
# Limit resources to share GPU server
mlenv up \
  --gpu 0,1 \        # Use only GPUs 0 and 1
  --memory 32g \     # Max 32GB RAM
  --cpus 8.0         # Max 8 CPU cores
```

### Development + Production Setup
```bash
# Development (with Jupyter, TensorBoard)
mlenv up \
  --requirements requirements-dev.txt \
  --port 8888:8888,6006:6006 \
  --verbose

# Production (lean, specific resources)
mlenv up \
  --requirements requirements.txt \
  --gpu 0 \
  --memory 16g \
  --no-user-mapping  # If needed for deployment
```

## 📊 Monitoring & Debugging

### Check Container Status
```bash
mlenv status

# Output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Container: ngc-myproject-a3f8c21d
# Status: running
# Workdir: /home/user/projects/myproject
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# GPU Status:
# index, name, utilization.gpu, memory.used, memory.total
# 0, NVIDIA A100, 45%, 12000 MiB, 40960 MiB
```

### View Logs
```bash
# NGC manager logs
mlenv logs

# Docker container logs
docker logs ngc-myproject-a3f8c21d

# Follow logs in real-time
docker logs -f ngc-myproject-a3f8c21d
```

### GPU Monitoring
```bash
# Inside container
mlenv exec -c "watch -n 1 nvidia-smi"

# Or use gpustat
mlenv exec -c "pip install gpustat && gpustat -i 1"
```

## 🐛 Troubleshooting

### Container won't start
```bash
# Check Docker daemon
docker info

# Check NVIDIA runtime
docker info | grep -i nvidia

# View detailed logs
mlenv up --verbose
mlenv logs
```

### GPU not detected
```bash
# Verify NVIDIA driver
nvidia-smi

# Test GPU in Docker
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi

# If failed, reinstall NVIDIA Container Toolkit:
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

### Port already in use
```bash
# Find what's using the port
lsof -ti:8888

# Kill the process
lsof -ti:8888 | xargs kill -9

# Or use a different port
mlenv up --port 8889:8888
```

### Permission denied errors
```bash
# Files created in container have wrong ownership?
# By default runs as your user, but if you need root:
mlenv up --no-user-mapping

# Fix existing permissions
mlenv exec -c "chown -R $(id -u):$(id -g) /workspace"
```

### Requirements won't update
```bash
# Force reinstall
mlenv up --force-requirements

# Or remove and recreate
mlenv rm
mlenv up --requirements requirements.txt
```

### Out of memory
```bash
# Check GPU memory
mlenv exec -c "nvidia-smi"

# Increase shared memory (edit script line 83):
--shm-size=32g  # default is 16g

# Or reduce batch size in your code
```

### Container name collision
The script uses directory hash to prevent this, but if you renamed your project:
```bash
# List all NGC containers
docker ps -a | grep ngc-

# Remove old ones
docker rm -f ngc-oldname-12345678
```

## 🔒 Security Best Practices

1. **Use `.gitignore`**:
```bash
# .gitignore
.mlenv/            # MLEnv state and logs
.devcontainer/     # Auto-generated VS Code config
.env              # Environment variables
*.pth             # PyTorch checkpoints
*.ckpt            # Model checkpoints
```

2. **Environment Variables**: Never commit API keys. Use `--env-file` with `.env` in `.gitignore`.

3. **User Mapping**: Default runs as your user (not root). Only use `--no-user-mapping` when necessary.

4. **Network Isolation**: Ports are only exposed on localhost by default. For remote access, use SSH tunneling:
```bash
# On remote server
mlenv up --port 8888:8888

# On local machine
ssh -L 8888:localhost:8888 user@remote-server

# Access via localhost:8888
```

## 🎯 Best Practices

### Project Structure
```
my-ml-project/
├── mlenv                 # This script
├── requirements.txt      # Python dependencies
├── .env                 # Environment variables (gitignored)
├── .gitignore           # Ignore .mlenv/, .devcontainer/, .env
├── train.py             # Training script
├── evaluate.py          # Evaluation script
├── data/                # Dataset
├── models/              # Saved models
├── notebooks/           # Jupyter notebooks
├── .mlenv/              # MLEnv state (gitignored)
│   ├── mlenv.log        # Debug logs
│   ├── devcontainer.json # VS Code config backup
│   └── init.sh          # Container init script
└── .devcontainer/       # VS Code Dev Container (auto-generated, gitignored)
    └── devcontainer.json
```

### Workflow
```bash
# 1. Setup (once per project)
mlenv up --requirements requirements.txt --port 8888:8888

# 2. Develop
mlenv jupyter  # or mlenv exec

# 3. When done for the day
mlenv down

# 4. Next day
mlenv up  # Fast startup, requirements cached
mlenv exec

# 5. Clean slate (if needed)
mlenv rm
mlenv up --force-requirements
```

### Version Control
```bash
# Commit the script with your project
git add mlenv requirements.txt
git commit -m "Add NGC container manager"

# Others can use it
git clone <your-repo>
cd <your-repo>
chmod +x ngc
./mlenv up --requirements requirements.txt
```

## 🚧 Known Limitations

Current version has a few limitations we're aware of:

- **Manual updates** - No built-in update mechanism (requires git pull + reinstall)
- **No config file** - Can't set persistent defaults (`.ngcrc` planned)
- **Manual completion reload** - Shell completions require terminal restart
- **Container logs** - No built-in log aggregation (use `docker logs` or `mlenv logs`)

**Note:** This tool is designed for Linux systems with NVIDIA GPUs. macOS and Windows native are not supported. Windows users should use WSL2 with NVIDIA GPU support.

See the [Roadmap](#-roadmap) below for planned improvements.

## 🗺️ Roadmap

### v1.1.0 (Current Release) ✨

**New Features:**
- ✅ **VS Code Dev Containers** - Auto-generate `.devcontainer/devcontainer.json` for seamless IDE integration
- ✅ **Smart Jupyter** - `mlenv jupyter` auto-creates containers with port forwarding (no `mlenv up` needed)
- ✅ **Auto-port detection** - Jupyter automatically finds and uses forwarded ports
- ✅ **Container auto-recreation** - Rebuilds containers with correct ports if needed

### v1.2 (Next Release)
- [ ] **Auto-update mechanism** - `mlenv update` to pull latest version
- [ ] **Enhanced status** - Show resource usage (CPU, memory, GPU utilization)
- [ ] **Better error messages** - Contextual help and suggestions

### v1.3 (Planned)
- [ ] **Config file support** - `~/.ngcrc` for default settings
- [ ] **Project templates** - `mlenv init --template pytorch|tensorflow|transformers`
- [ ] **Auto GPU detection** - `mlenv up --auto-gpu` to find free GPUs
- [ ] **Better testing** - Full integration test suite

### v2.0 (Future)
- [ ] **Multi-container** - Support for related services (db, web, training)
- [ ] **Experiment tracking** - Built-in W&B, MLflow integration
- [ ] **GPU scheduling** - Wait for GPU availability
- [ ] **Jupyter extensions** - Auto-install popular extensions
- [ ] **Central management** - Team dashboard for shared servers
- [ ] **Container snapshots** - Save/restore container state
- [ ] **Cloud integration** - Easy deployment to cloud GPU providers

### Want a Feature?
Open an issue describing your use case, or submit a PR! Popular requests get prioritized.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup
```bash
git clone https://github.com/your-username/mlenv.git
cd mlenv
chmod +x ngc

# Test locally
./mlenv up --verbose
./mlenv status
```

### Priority Areas
We'd especially appreciate help with:
- **Windows WSL2** - Testing and documentation improvements
- **Shell completions** - Improvements for zsh/fish
- **Test coverage** - More comprehensive test suite
- **Documentation** - Examples for specific frameworks (Transformers, Stable Diffusion, etc.)

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Built on top of [NVIDIA NGC containers](https://catalog.ngc.nvidia.com/)
- Inspired by Docker Compose and development container workflows
- Uses [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-username/mlenv/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/mlenv/discussions)
- **Documentation**: See `QUICKSTART.md` and `IMPROVEMENTS.md`

## 🔗 Related Projects

- [nvidia-docker](https://github.com/NVIDIA/nvidia-docker) - NVIDIA Container Toolkit
- [docker-compose](https://docs.docker.com/compose/) - Multi-container orchestration
- [Dev Containers](https://containers.dev/) - VS Code development containers

---

**Made with ❤️ for the ML/DL community**