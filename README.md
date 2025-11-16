# Comparatron - Digital Optical Comparator

Enhanced digital optical comparator software with CNC control for Arduino/GRBL-based systems.

## Overview

Comparatron is an advanced optical comparator that combines:
- High-resolution camera capture and display
- Precision CNC control via Arduino/GRBL
- Web-based interface accessible from any device
- DXF export for CAD integration
- Virtual environment management with split archives for GitHub

## Quick Start

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/darkdrago74/comparatron-optimised.git
   cd comparatron-optimised
   ```

2. Install dependencies:
   ```bash
   cd dependencies/
   chmod +x install_dependencies_universal.sh
   ./install_dependencies_universal.sh
   ```
   
   This script automatically detects your system (Fedora, Raspberry Pi, or other Linux) and installs appropriate dependencies.

3. After installation, you'll need to log out and back in for proper serial port permissions.

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

## Virtual Environment Management

The project uses a virtual environment split into 20MB chunks to comply with GitHub's 25MB file limit:

- Virtual environment: `comparatron_env/` (created in project root)
- Split files: `dependencies/venv_splits/`
- Installation recreates the environment from split files automatically

### Updating Virtual Environment

If dependencies change:
```bash
# Modify requirements in installation script
# Then rerun split script
cd dependencies/
./split_venv.sh  # Creates new 20MB chunks
```

## Serial Communication Setup

### Power Requirements
- **USB Connection**: Provides data communication
- **Main Power (12V/24V)**: Required for motor and driver operation
- Both connections are required for full functionality

### Permissions
The installation script adds your user to required groups:
- `dialout` group for serial port access
- `video` group for camera access

If experiencing permission issues:
```bash
sudo usermod -a -G dialout $USER
sudo usermod -a -G video $USER
```
Log out and log back in for changes to take effect.

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
│   ├── install_dependencies_universal.sh  # Universal installer
│   ├── install_dependencies_generic.sh    # Generic installer  
│   ├── split_venv.sh                    # Split venv script
│   └── venv_splits/                     # Split virtual env files
├── documentation/         # Project documentation
└── laserweb4/            # Optional LaserWeb4 integration
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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

See the LICENSE file for licensing information.

## Support

For issues or questions, please open an issue on the GitHub repository.