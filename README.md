# Comparatron - Digital Optical Comparator

Enhanced digital optical comparator software with CNC control for Arduino/GRBL-based systems.

## Overview

Comparatron is an advanced optical comparator that combines:
- High-resolution camera capture and display
- Precision CNC control via Arduino/GRBL
- Web-based interface accessible from any device
- DXF export for CAD integration
- DXF export for CAD integration

The project also includes optional integration with LaserWeb4 for additional CNC control capabilities:
- **LaserWeb4 works best with Node.js v18.x** for proper serial communication with GRBL
- LaserWeb runs on port 8000 by default
- Provides g-code visualization and advanced motion control
- Installation script can set up LaserWeb as a systemd service on Raspberry Pi systems

## Quick Start

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/darkdrago74/comparatron-optimised.git
    cd comparatron-optimised
    ```

2.  **Run the unified installation script:**
    ```bash
    chmod +x install.sh
    ./install.sh
    ```
    This script will automatically detect your system:
    *   **Linux (Fedora, Ubuntu, etc.)**: Install system dependencies and Python packages
    *   **Raspberry Pi**: Install system dependencies, Python packages, and optional systemd service for boot startup

3.  **Log out and log back in:**
    This is required for the user group changes (`video`, `dialout`) to take effect, which are necessary for camera and serial port access.

### Uninstallation

To remove Comparatron and its components:
```bash
cd dependencies
chmod +x uninstall.sh
./uninstall.sh
```

The uninstallation script will:
- Stop and remove the systemd service (if installed)
- Remove the system-wide `comparatron` command
- Remove user from system groups (dialout, video, gpio) if LaserWeb4 is not installed
- Optionally remove Python packages with the `--remove-all` flag
- Clean up configuration files

### Running the Application

**Manual start:**
```bash
python main.py
```

**On Raspberry Pi with auto-start enabled**, the application starts automatically on boot. Access it at `http://<your-pi-ip-address>:5001`.

**Manual access**: Open a web browser to `http://localhost:5001`.

## Easy Launch Command

After installation, you can launch Comparatron from any directory using the `comparatron` command:

```bash
# Launch Comparatron from any location
comparatron

# Force start even if already running
comparatron force
```

This command automatically detects the Comparatron installation directory and runs the main application.

## Installation

### Prerequisites:
- git (install with appropriate command for your system):
  - **Debian/Ubuntu**: `sudo apt install git`
  - **Fedora/RHEL**: `sudo dnf install git`

The unified installer will automatically handle all other requirements (Python 3, pip, dependencies).

### Main Installation (single comprehensive script):

First, clone the repository:
```bash
git clone https://github.com/darkdrago74/comparatron-optimised.git
cd comparatron-optimised
```

Then run the unified installation script:
```bash
chmod +x install.sh
./install.sh
```

The unified installer:
- Checks for existing installations and can fix issues
- Automatically installs Python 3 and pip if needed
- Installs all Python dependencies and system requirements
- Sets up systemd service for boot auto-start (optional)
- Creates system-wide `comparatron` command
- Runs comprehensive functionality tests (replaces comparatron_test.sh functionality)
- Can automatically uninstall and reinstall if issues are detected
- Cleans up partial installations if installation fails
- Automatically recovers from package installation issues (such as PIL/Pillow installation failures)


## Operating System Support

The installation script automatically detects your system and configures appropriately:

- **Linux (Ubuntu/Fedora/etc.)**: Full installation with all dependencies
- **Raspberry Pi**: Optimized installation with Pi-specific optimizations and optional boot service
- **Other systems**: Fallback installation using available package managers

### OS Detection and Installation Details

The unified installer automatically:
- Detects your operating system and package manager
- Installs appropriate system dependencies (using apt, dnf, etc.)
- Uses optimized package sources (like piwheels for Raspberry Pi)
- Configures system-specific settings (GPIO access on Raspberry Pi)
- Sets up user groups for hardware access (serial, camera, GPIO)
- Creates system-wide command (`comparatron`)
- Sets up systemd service for auto-start (optional)
- Runs comprehensive functionality tests

## Key Features

- **Web Interface**: Accessible from any device on your network
- **Camera Support**: Multiple camera detection and preview
- **CNC Control**: Direct control of GRBL-based CNC machines
- **Serial Communication**: Robust error handling with power state detection
- **DXF Export**: Point measurements exported to CAD format
- **Cross-platform**: Works on Fedora, Raspberry Pi, and other Linux systems

## Software Requirements

### Prerequisites
Before installation, ensure you have these software packages installed:

**For Fedora/RHEL systems:**
```bash
sudo dnf install python3 python3-pip git
```

**For Debian/Ubuntu/Raspberry Pi systems:**
```bash
sudo apt update && sudo apt install python3 python3-pip git
```

**Required Python version:** Python 3.8 or higher (Python 3.10+ recommended)

**System libraries (automatically installed by the script):**
The installation script will automatically install additional system libraries as needed, including:
- build-essential (compilation tools)
- libatlas-base-dev (for optimized linear algebra)
- libhdf5-dev (for data storage)
- libgstreamer1.0-dev (for video processing)
- libavcodec-dev, libavformat-dev, libswscale-dev (for video handling)
- libv4l-dev, libxvidcore-dev, libx264-dev (for camera support)
- libjpeg-dev, libpng-dev, libtiff5-dev (for image handling)

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

## Auto-start Configuration

Comparatron offers two distinct ways to run automatically:

### Command-line Auto-start
This allows you to start Comparatron manually from the terminal using the `comparatron` command. This launches the application when you run the command, but it doesn't start automatically when the system boots:
```bash
# Launch Comparatron from any directory
comparatron

# Force start even if already running
comparatron force
```

### Boot Auto-start (systemd service)
This allows Comparatron to start automatically when your system boots up via a systemd service. This is configured during installation and runs in the background without user intervention:

#### Web Interface Control
The web interface includes a button to toggle boot auto-start functionality directly from the GUI.

#### Command Line Control
```bash
# Enable auto-start on boot
python3 main.py ON

# Disable auto-start on boot
python3 main.py OFF
```

#### Systemctl Control
```bash
# Enable auto-start on boot
sudo systemctl enable comparatron.service

# Disable auto-start on boot
sudo systemctl disable comparatron.service

# Start the service now (without rebooting)
sudo systemctl start comparatron.service

# Stop the service now (without affecting boot setting)
sudo systemctl stop comparatron.service

# Check if service is currently active
systemctl is-active comparatron.service

# Check if service is enabled for auto-start on boot
systemctl is-enabled comparatron.service
```

The difference is important: command-line auto-start refers to the easy launch command that works from any directory, while boot auto-start refers to the systemd service that starts the application automatically when the system boots.

## Easy Launch Command

For convenience, you can launch Comparatron from any directory using the `comparatron` command:

```bash
# Launch Comparatron from any location
comparatron

# Force start even if already running
comparatron force
```

This command automatically detects the Comparatron installation directory and runs the main application.

Note: This is the command-line auto-start functionality, which is distinct from the boot auto-start feature that starts Comparatron automatically when your system boots up.

## Command Extensions

Additional commands were added to enhance the functionality:

### GRBL Parameter/Settings Access
- **View all settings**: Send `$$` command via the raw command interface
- **View all parameters**: Send `$#` command via the raw command interface

### Camera Functionality
- **Refresh camera detection**: Web interface button to detect newly connected cameras without restarting
- **Multiple backend support**: Improved compatibility with various camera types

## Project Structure

```
comparatron-optimised/
├── main.py                 # Main application entry point
├── gui_flask.py           # Web interface
├── camera_manager.py      # Camera handling
├── serial_comm.py         # Serial communication with CNC
├── machine_control.py     # Machine control commands
├── dxf_handler.py         # DXF file processing
├── DOCUMENTATION.md       # Detailed project documentation
├── comparatron_env/       # Virtual environment (created by installer)
├── install.sh             # Main unified installer (Linux & Raspberry Pi)
├── dependencies/          # Additional scripts and dependencies
│   ├── uninstall.sh       # Uninstaller
│   ├── requirements.txt   # Python package requirements (exact versions)
│   └── requirements-simple.txt  # Alternative requirements (compatible versions)
└── laserweb4/            # Optional LaserWeb4 integration
```


## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

See the LICENSE file for licensing information.

## LaserWeb4 Integration

Comparatron includes optional integration with LaserWeb4 for enhanced CNC control capabilities. The installation process has been enhanced with a unified script that handles both installation and uninstallation.

### LaserWeb4 Installation

To install LaserWeb4 with the enhanced installation script:

1. Navigate to the laserweb4 directory:
   ```bash
   cd laserweb4
   ```

2. Run the installation script:
   ```bash
   chmod +x install_laserweb4.sh
   ./install_laserweb4.sh
   ```

3. The script will present you with options:
   - Install LaserWeb4
   - Uninstall LaserWeb4
   - Check current installation status

4. If installing, you'll be prompted to choose between:
   - Node.js 16 (recommended for LaserWeb4)
   - Node.js 18 (with additional libraries)

5. The script will handle all dependencies, including required libraries (libusb-1.0-0-dev and libudev-dev) for proper serial communication.

### LaserWeb4 Uninstallation

To completely remove LaserWeb4:

1. Navigate to the laserweb4 directory:
   ```bash
   cd laserweb4
   ```

2. Run the uninstallation script:
   ```bash
   chmod +x uninstall_laserweb4.sh
   ./uninstall_laserweb4.sh
   ```

The uninstallation script will:
- Stop and disable the LaserWeb service
- Remove LaserWeb directories and configuration files
- Remove nginx configuration if set up
- Remove start scripts
- Optionally remove Node.js if installed by the script
- Clean up npm cache and global packages
- Optionally remove user from dialout group

### Checking Installation Status

To check the current status of LaserWeb4 installation:
1. Run the installation script and select option 3
2. The script will report on:
   - Node.js version installed
   - npm version
   - LaserWeb directories
   - Service status
   - Required libraries

## Support

For issues or questions, please open an issue on the GitHub repository.