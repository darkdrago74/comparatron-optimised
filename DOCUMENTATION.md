# Comparatron - Digital Optical Comparator Documentation

Enhanced digital optical comparator software with CNC control for Arduino/GRBL-based systems.

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Key Features](#key-features)
4. [System Requirements](#system-requirements)
5. [Virtual Environment Management](#virtual-environment-management)
6. [Serial Communication Setup](#serial-communication-setup)
7. [Usage](#usage)
8. [Troubleshooting](#troubleshooting)
9. [Project Structure](#project-structure)
10. [Development](#development)
11. [Windows Executable Creation](#windows-executable-creation)

## Overview

Comparatron is an advanced optical comparator that combines:
- High-resolution camera capture and display
- Precision CNC control via Arduino/GRBL
- Web-based interface accessible from any device
- DXF export for CAD integration
- Virtual environment management with split archives for GitHub

The project also includes optional integration with LaserWeb4 for additional CNC control capabilities:
- LaserWeb runs on port 8080 by default
- Provides g-code visualization and advanced motion control
- Installation script can set up LaserWeb as a systemd service on Raspberry Pi systems

## Quick Start

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/darkdrago74/comparatron-optimised.git
   cd comparatron-optimised
   ```

   additionally before starting :
   ### Permissions possible issues
The installation script adds your user to required groups:
- `dialout` group for serial port access
- `video` group for camera access

If experiencing permission issues:
```bash
sudo usermod -a -G dialout $USER
sudo usermod -a -G video $USER
```
Log out and log back in for changes to take effect.

2. Install dependencies:
   ```bash
   cd dependencies/
   chmod +x install_dependencies_universal.sh
   ./install_dependencies_universal.sh
   ```

   This script automatically detects your system (Fedora, Raspberry Pi, or other Linux) and installs appropriate dependencies. It also handles virtual environment recombination from split files if available.

3. After installation, you'll need to log out and back in for proper serial port permissions.

### Uninstallation

If you need to remove Comparatron and all its components:
```bash
cd dependencies/
chmod +x uninstall.sh
./uninstall.sh
```

This will remove systemd services, virtual environments, and other configuration files created during installation.

### Running the Application

Start the web interface:
```bash
python3 main.py
```

Access the interface at: `http://localhost:5001`

## Key Features

- **Web Interface**: Accessible from any device on your network
- **Camera Support**: Multiple camera detection and preview
- **CNC Control**: Direct control of GRBL-based CNC machines
- **Serial Communication**: Robust error handling with power state detection
- **DXF Export**: Point measurements exported to CAD format
- **Cross-platform**: Works on Fedora, Raspberry Pi, and other Linux systems

## System Requirements

### Hardware Requirements
- Computer with USB ports for Arduino/GRBL CNC controller
- Main power supply (12V/24V) for GRBL shield motors/drivers (separate from USB power)
- Compatible camera (USB webcam, industrial camera, etc.)

### Software Requirements
- Python 3.8+
- Git
- For Fedora: `sudo dnf install python3 python3-pip python3-devel git`
- For Raspberry Pi: `sudo apt install python3 python3-pip python3-dev git`

### System Permissions (Required for Operation)
- **Serial Port Access**: After installation, you must be added to the dialout group for serial communication with Arduino/GRBL:
  ```bash
  sudo usermod -a -G dialout $USER
  ```
  **Important: You need to log out and log back in for the group changes to take effect.** Without this, the system won't be able to communicate with your Arduino/GRBL CNC controller via serial port. Check that you're in the group after logging back in:
  ```bash
  groups $USER | grep dialout
  ```

- **Camera Access**: If cameras are not detected, you may need to add your user to the video group:
  ```bash
  sudo usermod -a -G video $USER
  ```
  Then log out and log back in to apply the permissions.

## Virtual Environment Management

The project uses a virtual environment split into 20MB chunks to comply with GitHub's 25MB file limit:

- Virtual environment: `comparatron_env/` (created in project root)
- Split files: `dependencies/venv_splits/`
- Installation scripts automatically recombine the environment from split files if available

### Updating Virtual Environment

If dependencies change:
```bash
# Modify requirements in installation script
# Then rerun split script
cd dependencies/
./split_venv.sh  # Creates new 20MB chunks
```

### Virtual Environment Recombination

During installation, the system automatically detects and recombines the virtual environment:
1. Checks for existing `comparatron_env` directory
2. If not found, looks for `dependencies/venv_splits/comparatron_env_main.tar.gz`
3. If not found, looks for split files (`comparatron_env_part_*`) and recombines them
4. Extracts the virtual environment to the project root

### PEP 668 Compliance and ARM Optimization

The installation scripts now properly handle PEP 668 compliance on newer Linux systems (including Raspberry Pi OS bookworm) by:
- Using the `--break-system-packages` flag when installing packages in virtual environments
- Ensuring the virtual environment is properly activated before package installation
- Adding verification steps in the validation script to check package installation
- Enhanced pip command handling to ensure proper installation within the virtual environment
- ARM/ARM64-specific optimizations with fallback mechanisms for OpenCV installation
- Improved piwheels integration for faster ARM package installation
- Better dependency conflict resolution for Raspberry Pi systems
- Absolute path resolution to ensure proper virtual environment activation
- Multiple fallback approaches for robust installation across different systems

## Serial Communication Setup

### Power Requirements
- **USB Connection**: Provides data communication
- **Main Power (12V/24V)**: Required for motor and driver operation
- Both connections are required for full functionality


## Usage

### Web Interface
1. Start the application: `python3 main.py`
2. Open browser to `http://localhost:5001`
3. Select camera from available devices
4. Connect to CNC via serial port (requires both USB and main power)
5. Home the machine using the HOME button
6. Capture points using the interface controls
7. Export measurements as DXF file

### CNC Controls
- **Home**: Move all axes to home position (`$H` command)
- **Unlock**: Unlock machine from alarm state (`$X` command)
- **Jog**: Manual axis movement
- **Feed Rate**: Set movement speed

### Error Messages
Common error messages and solutions:
- **"No response from GRBL controller"**: Check main power (12V/24V) connection
- **"Device detected but no response"**: Verify power connections to motors/drivers
- **"Permission denied"**: Ensure user is in `dialout` group

## Troubleshooting

### Camera Not Detected
1. Check camera connections
2. Verify user is in `video` group: `groups $USER | grep video`
3. Restart camera service or reboot if needed

### Serial Connection Issues
1. Verify USB cable connection
2. Ensure main power (12V/24V) is connected to CNC shield
3. Check that user is in `dialout` group: `groups $USER | grep dialout`
4. Look for proper device in `/dev/ttyUSB*` or `/dev/ttyACM*`

### Web Interface Not Loading
1. Check firewall settings for port 5001
2. Verify Flask installation in virtual environment
3. Check browser console for JavaScript errors

## Project Structure

```
comparatron-optimised/
├── main.py                 # Main application entry point
├── gui_flask.py           # Web interface
├── camera_manager.py      # Camera handling
├── serial_comm.py         # Serial communication with CNC
├── machine_control.py     # Machine control commands
├── dxf_handler.py         # DXF file processing
├── validate_optimization.py # Installation validation
├── comparatron_env/       # Virtual environment (not in repo)
├── dependencies/          # Installation scripts and split venv
│   ├── install_dependencies_universal.sh  # Universal installer with recombination
│   ├── install_dependencies_generic.sh    # Generic installer with recombination
│   ├── uninstall.sh                       # Complete uninstallation script (removes both Comparatron and LaserWeb4)
│   ├── split_venv.sh                    # Split venv script
│   └── venv_splits/                     # Split virtual env files
├── documentation/         # Project documentation
└── laserweb4/            # Optional LaserWeb4 integration (run on port 8080)
```

## Development

### Adding Dependencies
Add new packages by modifying the installation scripts in `dependencies/` and recreating the virtual environment split:
```bash
cd dependencies/
./split_venv.sh
```

### Validation
Run the validation script to check all components:
```bash
python3 validate_optimization.py
```

## Windows Executable Creation

This document explains how to create a standalone Windows executable for the Comparatron Flask-based software using PyInstaller.

### Important Note: Web-Based Architecture

The current Comparatron uses a **Flask web interface** which creates a web server that can be accessed through any browser at `http://localhost:5001`. Unlike traditional desktop applications, this creates a web server that runs locally but requires a browser for the interface.

### Prerequisites

- Python installed on your Windows system (3.7 or later)
- All required dependencies installed (numpy, flask, pyserial, opencv-python, ezdxf, pillow)
- PyInstaller installed (install with `pip install pyinstaller`)

### Creating the Executable

#### Option 1: Flask Server Executable (Primary Method)
This creates an executable that starts the Flask server:

```bash
pyinstaller main.py --name ComparatronWeb --add-data "templates;templates" --add-data "LICENSE;." --add-data "README.md;."
```

#### Option 2: One-File Executable
This creates a single .exe file that contains everything:

```bash
pyinstaller main.py -F --name ComparatronWeb --add-data "templates;templates" --add-data "LICENSE;." --add-data "README.md;."
```

### PyInstaller Options Explained

- `-F` or `--onefile`: Creates a single executable file (larger, slower startup)
- `--name`: Sets the name of the executable
- `--add-data`: Includes additional files/directories in the executable
  - Format on Windows: `"source;destination"`
  - Format on Linux/Mac: `"source:destination"`
- `--hidden-import`: Explicitly include modules that PyInstaller might miss
- `--collect-all`: Collect all files from a package

### Recommended Command

For the best results with the Comparatron Flask application, use this command:

```bash
pyinstaller main.py --name ComparatronFlask --add-data "templates;templates" --add-data "LICENSE;." --add-data "README.md;." --hidden-import=flask --hidden-import=cv2 --hidden-import=PIL --hidden-import=serial --hidden-import=ezdxf
```

### Alternative: Enhanced Launcher Batch File

Since the Flask web interface requires a browser, consider creating both the executable and a batch file that starts it and opens the browser automatically:

Create `launch_comparatron.bat`:
```batch
@echo off
REM Comparatron Launcher
REM Starts the Flask server and opens the browser automatically

echo Starting Comparatron Flask Server...
echo Opening browser at http://localhost:5001

REM Change to the script's directory
cd /d "%~dp0"

REM Activate virtual environment if it exists
if exist "comparatron_env\Scripts\activate.bat" (
    call comparatron_env\Scripts\activate.bat
)

REM Start the Flask server in the background
start python main.py

REM Wait for server to start, then open browser
timeout /t 3 /nobreak >nul
start http://localhost:5001

echo Comparatron is running. Browse to http://localhost:5001
echo Close this window to stop the server.
pause
```

### Troubleshooting

#### Common Issues and Solutions:

1. **Missing templates error**
   - Ensure `--add-data "templates;templates"` is included
   - Flask needs access to the templates directory

2. **Import errors after building**
   - Add `--hidden-import=module_name` for each missing module
   - Common ones: `--hidden-import=flask`, `--hidden-import=cv2`

3. **Large file size**
   - Flask applications tend to be larger due to web framework requirements
   - Consider distributing as a directory instead of single file

4. **Template directory not found**
   - If using one-file approach, some resources might not resolve properly
   - Consider using directory-based executable for reliability

### Distribution

After building, distribute:
- The executable in the `dist/` folder
- A shortcut or batch file that opens the browser to `http://localhost:5001`
- Inform users that the interface will be available in their browser

### User Experience

When users run the executable:
1. A console window appears showing server startup
2. The Flask server starts listening on `http://localhost:5001`
3. Users access the interface by opening a browser
4. All functionality is available through the web interface

### Important Considerations

- **Internet Browser Required**: Users must have a web browser installed
- **Local Network Access**: The interface can be accessed from other devices on the same network
- **Multiple Interfaces**: Both the Flask web interface and any browser can access the same server
- **Port Configuration**: The server runs on port 5001 by default
