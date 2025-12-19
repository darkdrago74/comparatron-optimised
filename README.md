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
    cd dependencies
    chmod +x install_dependencies.sh
    ./install_dependencies.sh
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
- Sets up systemd service for auto-start (optional)
- Creates system-wide `comparatron` command
- Runs comprehensive functionality tests (replaces comparatron_test.sh functionality)
- Can automatically uninstall and reinstall if issues are detected
- Cleans up partial installations if installation fails

## Legacy Installation (for reference only)

For historical purposes, the original installation script is available in the dependencies directory:
```bash
cd dependencies
chmod +x install_dependencies.sh
./install_dependencies.sh
```

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

## Auto-start Configuration

Comparatron supports auto-start on boot via systemd service with multiple control options:

### Web Interface Control
The web interface includes a button to toggle auto-start functionality directly from the GUI.

### Command Line Control
```bash
# Enable auto-start
python3 main.py ON

# Disable auto-start
python3 main.py OFF
```

### Systemctl Control
```bash
# Enable auto-start on boot
sudo systemctl enable comparatron.service

# Disable auto-start on boot
sudo systemctl disable comparatron.service

# Start the service now
sudo systemctl start comparatron.service

# Check service status
systemctl is-active comparatron.service
systemctl is-enabled comparatron.service
```

## Easy Launch Command

For convenience, you can launch Comparatron from any directory using the `comparatron` command:

```bash
# Launch Comparatron from any location
comparatron

# Force start even if already running
comparatron force
```

This command automatically detects the Comparatron installation directory and runs the main application.

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
├── dependencies/          # Installation scripts and dependencies
│   ├── install_dependencies.sh  # Unified installer (Linux & Raspberry Pi)
│   ├── uninstall.sh             # Uninstaller
│   ├── requirements.txt         # Python package requirements (exact versions)
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

## Support

For issues or questions, please open an issue on the GitHub repository.