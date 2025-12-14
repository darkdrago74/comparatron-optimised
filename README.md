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
├── DOCUMENTATION.md       # Complete project documentation
├── dependencies/          # Installation scripts and dependencies
│   ├── install_dependencies.sh  # Unified installer (Linux & Raspberry Pi)
│   ├── uninstall.sh             # Uninstaller
│   └── requirements.txt         # Python package requirements (exact versions)
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
