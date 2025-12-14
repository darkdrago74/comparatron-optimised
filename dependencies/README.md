# Comparatron Dependencies and Setup

This folder contains the necessary scripts and information to set up Comparatron on different systems.

## System Prerequisites

Before running the installation scripts, ensure you have these system packages installed:

### For Fedora Systems:
```bash
sudo dnf install python3 python3-pip python3-devel git nodejs npm nginx
```

### For Raspberry Pi (Bookworm):
```bash
sudo apt install python3 python3-pip python3-dev git nodejs npm nginx
```

## Large Virtual Environment Management

Due to GitHub's 50MB file size limit, we provide scripts to manage large virtual environments:

### For Creating Splits (for GitHub upload):
```bash
./split_venv.sh
```
This creates the `venv_splits` directory with chunks of the virtual environment, each under 50MB.

## Installation Scripts:

### Primary (Recommended):
- `install_dependencies_universal.sh` - Automatic system detection and optimized installation for any Linux distribution (Fedora, RPi, etc.)
  - Automatically handles recombination from chunks if they exist
  - Detects system type and installs appropriate dependencies
  - Creates isolated virtual environment with all required packages

### Backup/Basic:
- `install_dependencies_generic.sh` - Basic installation for systems with custom configurations
  - Handles recombination from chunks if they exist  
  - For systems where system detection might not work perfectly

### System Management:
- `uninstall.sh` - Complete removal of all Comparatron and LaserWeb4 components