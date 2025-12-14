# Comparatron - Complete Project Documentation

## Overview
Comparatron is an advanced digital optical comparator that combines high-resolution camera capture, precision CNC control via Arduino/GRBL, and a web-based interface accessible from any device.

## Installation Process

### Unified Installation Script
The unified installation script (`install_dependencies.sh`) automatically detects your system type and performs the appropriate installation:

- **Linux Desktop/Server (Fedora, Ubuntu, etc.)**: Installs system dependencies and Python packages directly to system Python
- **Raspberry Pi**: Installs system dependencies, Python packages, and offers to set up auto-start service

### Module Versions
The installation uses exact package versions from `requirements.txt`:
```
blinker==1.9.0
click==8.3.1
ezdxf==1.4.3
Flask==3.1.2
fonttools==4.61.1
itsdangerous==2.2.0
Jinja2==3.1.6
MarkupSafe==3.0.3
numpy==2.2.6
opencv-python==4.12.0.88
pillow==12.0.0
pyparsing==3.2.5
pyserial==3.5
typing_extensions==4.15.0
Werkzeug==3.1.4
```

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

### System Permissions
- **Serial Port Access**: After installation, you must be added to the dialout group for serial communication with Arduino/GRBL
- **Camera Access**: If cameras are not detected, you may need to add your user to the video group

## Installation Validation

The `validate_optimization.py` script performs comprehensive validation:

1. **System Installation Check**: Verifies all required packages are available in system Python
2. **Module Import Tests**: Tests importing all required modules (cv2, numpy, flask, PIL, serial, ezdxf)
3. **Functional Tests**: Tests camera, serial, machine control, and DXF functionality
4. **Script Validation**: Confirms installation and uninstall scripts exist and are executable

## Raspberry Pi Specifics

### Auto-Start Service
On Raspberry Pi systems, the installation script offers to enable an auto-start service that launches Comparatron on boot. This service runs via systemd and is accessible at `http://<your-pi-ip-address>:5001`.

### Raspberry Pi OS (Bookworm) Optimizations
- Uses piwheels.org for faster package installation
- Optimizes for ARMv7 architecture
- Sets up proper GPIO access if available

## Key Features

- **Web Interface**: Accessible from any device on your network
- **Camera Support**: Multiple camera detection and preview
- **CNC Control**: Direct control of GRBL-based CNC machines
- **Serial Communication**: Robust error handling with power state detection
- **DXF Export**: Point measurements exported to CAD format
- **Cross-platform**: Works on Fedora, Raspberry Pi, and other Linux systems

### Web Interface
The main interface is Flask-based, accessible at `http://localhost:5001`

### Machine Control
- CNC movement control via GRBL/Arduino
- Jog distance and feed rate control
- Position reporting and status monitoring

### Camera Management
- Automatic camera detection
- Real-time preview
- Calibration support

### Serial Communication
- Robust error handling
- Power state detection
- Command queuing and response management

## Troubleshooting

### Service Management (Raspberry Pi)
- Check service status: `sudo systemctl status comparatron`
- Start service: `sudo systemctl start comparatron`
- Stop service: `sudo systemctl stop comparatron`
- Enable auto-start: `sudo systemctl enable comparatron`
- Disable auto-start: `sudo systemctl disable comparatron`

### Common Issues
- **Camera not detected**: Check video group membership with `groups $USER | grep video`
- **Serial port access denied**: Check dialout group membership with `groups $USER | grep dialout`
- **Web interface not accessible**: Verify firewall settings allow port 5001

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

## Support
For issues or questions, please open an issue on the GitHub repository.