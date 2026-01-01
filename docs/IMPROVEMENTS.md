# MLEnv - ML Environment Manager - Improvements Summary

## What's New

### 1. **Idempotent Requirements Installation** ✨
**Before:**
```bash
mlenv up  # installs requirements
mlenv down
mlenv up  # installs AGAIN (wasteful)
```

**After:**
```bash
mlenv up  # installs requirements (hash saved)
mlenv down
mlenv up  # skips (detects same file)
mlenv up --force-requirements  # force reinstall if needed
```

### 2. **Port Forwarding** 🌐
```bash
# Jupyter + TensorBoard
mlenv up --port 8888:8888,6006:6006

# Quick Jupyter command
mlenv jupyter
```

### 3. **Environment Variables** 🔐
```bash
# .env file
API_KEY=secret123
DB_HOST=localhost

# Use it
mlenv up --env-file .env
```

### 4. **GPU Device Selection** 🎮
```bash
# Use specific GPUs
mlenv up --gpu 0,1

# Or all (default)
mlenv up --gpu all
```

### 5. **Unique Container Names** 🏷️
**Before:** `ngc-myproject` (collision if same name in different dirs)  
**After:** `ngc-myproject-a3f8c21d` (includes directory hash)

### 6. **Run as Current User** 👤
No more root permission issues! Files created in container match your user/group.
```bash
# Default (as current user)
mlenv up

# As root (if needed)
mlenv up --no-user-mapping
```

### 7. **Resource Limits** 📊
```bash
# Prevent hogging system resources
mlenv up --memory 16g --cpus 4.0
```

### 8. **Execute Commands** 🚀
```bash
# Interactive shell
mlenv exec

# Run specific command
mlenv exec -c "python train.py --epochs 10"
mlenv exec -c "pip list | grep torch"
```

### 9. **Better Status Command** 📈
```bash
$ mlenv status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Container: ngc-myproject-a3f8c21d
Status: running
Workdir: /home/user/projects/myproject
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTAINER ID   IMAGE              STATUS        PORTS
3b4f8a2c1d9e   nvcr.io/nvidia...  Up 2 hours    0.0.0.0:8888->8888/tcp

GPU Status:
index, name, utilization.gpu, memory.used, memory.total
0, NVIDIA A100, 45%, 12000 MiB, 40960 MiB
```

### 10. **New Commands**
- `mlenv restart` - Quick restart
- `mlenv jupyter` - One-command Jupyter Lab
- `mlenv clean` - Remove artifacts
- `mlenv help` - Comprehensive help

### 11. **Better Error Handling** 🛡️
```bash
✖ Docker daemon is not running. Start Docker and try again.
✖ Requirements file not found: requirements.txt
✖ Failed to install requirements. Check logs: mlenv logs
```

### 12. **Improved Logging** 📝
- Timestamped debug logs
- Separate verbose/quiet modes
- Better visual indicators (✔ ✖ ⚠ ℹ)

### 13. **Auto-restart** 🔄
Container automatically restarts after system reboot (unless explicitly stopped).

## Breaking Changes
None! Backwards compatible with original commands.

## Migration Guide

### From original script:
```bash
# Old way
./mlenv up --requirements requirements.txt --verbose

# New way (same!)
./mlenv up --requirements requirements.txt --verbose

# But now you can also:
./mlenv up --requirements requirements.txt --port 8888:8888 --gpu 0
```

### Container naming:
- Old: `ngc-myproject`
- New: `ngc-myproject-a3f8c21d`
- To clean up old containers: `docker rm -f ngc-myproject`

## Installation

```bash
# Make executable
chmod +x ngc

# Optional: add to PATH
sudo mv ngc /usr/local/bin/
# or
echo 'alias ngc=/path/to/ngc' >> ~/.bashrc
```

## Common Workflows

### Deep Learning Development
```bash
# Full setup
mlenv up \
  --requirements requirements.txt \
  --port 8888:8888,6006:6006 \
  --gpu 0,1 \
  --memory 32g \
  --env-file .env

# Start Jupyter
mlenv jupyter

# Run training
mlenv exec -c "python train.py --config config.yaml"

# Monitor
mlenv status
```

### Quick Experimentation
```bash
mlenv up
mlenv exec
# ... experiment ...
mlenv down
```

### Clean Slate
```bash
mlenv rm
mlenv up --force-requirements
```

## Technical Improvements

1. **Hash-based requirement caching** - Only reinstalls if file changes
2. **Better keepalive** - Uses `sleep infinity` instead of `tail -f /dev/null`
3. **User/group mapping** - Avoids permission issues
4. **Restart policy** - Container survives reboots
5. **Error propagation** - Failures in pip install are caught
6. **Modular functions** - Easier to extend and maintain