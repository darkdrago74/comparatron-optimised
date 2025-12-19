# Comparatron - Complete Project Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation Process](#installation-process)
4. [System Configuration](#system-configuration)
5. [Hardware Integration](#hardware-integration)
6. [Software Modules](#software-modules)
7. [Command Extensions](#command-extensions)
8. [Troubleshooting](#troubleshooting)
9. [Optimizations](#optimizations)
10. [Contributing](#contributing)

## Overview

Comparatron is an advanced digital optical comparator that combines:
- High-resolution camera capture for visual inspection
- Precision CNC control via Arduino/GRBL interface
- Web-based interface accessible from any networked device
- DXF export for CAD integration
- Real-time coordinate measurement and recording

The project integrates with LaserWeb4 for additional CNC control capabilities with g-code visualization and advanced motion control.

## Architecture

The system consists of multiple interconnected modules:

### Core Components
- **Flask GUI**: Web interface providing access from any device
- **Camera Manager**: Handles camera detection, initialization, and video streaming
- **Serial Communicator**: Manages communication with GRBL-based CNC controllers
- **Machine Controller**: Translates high-level commands to GRBL commands
- **DXF Handler**: Processes and exports measurement points to CAD format

### Web Interface
- Built with Flask for cross-platform web access
- Accessible at http://localhost:5001
- Real-time camera feed display
- CNC control with jog commands
- Position tracking and point recording
- DXF export functionality

## Installation Process

### Prerequisites
- Python 3.8+
- Git
- System packages for OpenCV and camera support

### Quick Installation
1. Clone the repository
2. Run `dependencies/install_dependencies.sh`
3. Log out and back in (to apply group memberships)

### System-wide Installation
The installation script performs:
- System dependency installation (OpenCV, camera drivers, etc.)
- Python package installation via pip
- User group additions (video and dialout for camera/serial access)
- Optional systemd service for Raspberry Pi auto-start
- Validation of all required components

## System Configuration

### Auto-start Service
For systems using systemd (most Linux distributions including Raspberry Pi):

- **Enable auto-start**: `sudo systemctl enable comparatron.service`
- **Disable auto-start**: `sudo systemctl disable comparatron.service`
- **Start service**: `sudo systemctl start comparatron.service`
- **Check status**: `systemctl is-active comparatron.service`
- **View logs**: `sudo journalctl -u comparatron -f`

### User Groups
The installation adds the user to important groups:
- **video**: For camera access (required for camera functionality)
- **dialout**: For serial communication (required for CNC/GRBL control)

## Hardware Integration

### Camera Support
- Automatic detection of connected cameras
- Multiple camera support with selection dropdown
- Real-time preview with crosshair target
- Optimized for USB webcams and industrial cameras
- Supports various resolutions and frame rates

### CNC Control (GRBL/Arduino)
- Direct serial communication with Arduino/GRBL
- Standard baud rates (115200) for compatibility
- Robust error handling with power state detection
- Jog controls with adjustable distances
- Home, unlock, and other machine functions

### Serial Communication
- Automatic detection of available COM ports
- Robust connection handling with retry logic
- Power state detection to differentiate communication errors from power issues
- Command queuing and response management

## Software Modules

### main.py
Primary entry point with:
- Virtual environment detection and setup
- Auto-start service activation/deactivation
- System-wide command detection and handling

### gui_flask.py
Flask web interface with:
- Camera feed streaming
- CNC control interface
- Real-time coordinate display
- Point recording and visualization
- API endpoints for all functionality

### camera_manager.py
Camera handling with:
- Multiple camera detection algorithm
- Camera initialization and streaming
- Backend compatibility optimization
- Refresh functionality for newly connected cameras

### serial_comm.py
Serial communication with:
- Port detection and connection management
- Command transmission and response handling
- Power state detection algorithms
- GRBL-specific command implementations

### machine_control.py
CNC control commands with:
- Jog movements for X, Y, Z axes
- Feed rate management
- Position reporting
- GRBL command abstraction

### dxf_handler.py
CAD integration with:
- Point storage and management
- DXF file generation
- Export functionality
- Coordinate system handling

## Command Extensions

### GRBL Parameter/Settings Access
Two new commands have been added to access GRBL configuration:

**$$ Command**: Lists all GRBL settings
- Access via raw command interface: `$$`
- Returns all configurable parameters with current values
- Useful for debugging and configuration verification

**$# Command**: Lists all GRBL parameters
- Access via raw command interface: `$#`
- Returns current work coordinate offsets, probing results, etc.
- Essential for verifying machine state

### Camera Refresh Functionality
New camera detection algorithm includes:
- `refresh_camera_detection()` function to detect newly connected cameras
- Web interface button to trigger refresh without app restart
- Multi-backend approach (V4L2, GStreamer, FFmpeg) for better compatibility
- Fast detection with timeout handling for unresponsive cameras

### Easy Launch Command
The `comparatron` command provides:
- System-wide availability after installation
- Automatic installation directory detection
- Conflict prevention when already running
- Direct launch from any location

## Troubleshooting

### Common Issues

#### Camera Not Detected
1. Check if camera is physically connected: `ls -la /dev/video*`
2. Verify user is in video group: `groups $USER | grep video`
3. Add to video group: `sudo usermod -a -G video $USER`
4. Log out and log back in
5. Run the refresh camera function in the web interface

#### Serial Communication Issues
1. Verify Arduino/GRBL is connected and powered
2. Check if port is available: `ls -la /dev/tty{USB,ACM,S}*`
3. Confirm user is in dialout group: `groups $USER | grep dialout`
4. Add to dialout group: `sudo usermod -a -G dialout $USER`
5. Log out and log back in
6. Try different baud rates in the interface

#### Web Interface Not Accessible
1. Check if application is running: `ps aux | grep python`
2. Verify port 5001 is available: `netstat -tuln | grep 5001`
3. Check firewall settings if accessing remotely
4. Ensure Python dependencies are installed

### System Service Issues
1. Check service status: `systemctl is-active comparatron.service`
2. Check service logs: `sudo journalctl -u comparatron.service -f`
3. Verify user permissions for hardware access
4. Check installation completed successfully

## Optimizations

### Performance Improvements
- Camera frame rate optimization (15-30 FPS based on system)
- Efficient video streaming using multipart responses
- Hardware acceleration for image processing
- Optimized serial communication timeouts

### Cross-platform Compatibility
- Automatic platform detection
- System-specific optimization paths
- Compatible with Fedora, Raspberry Pi, and other Linux systems
- Consistent functionality across platforms

### Memory and Resource Management
- Efficient image processing with NumPy arrays
- Proper cleanup of camera and serial resources
- Optimized buffer management for video streaming
- Thread-safe concurrent operations

## Contributing

### Development Process
1. Fork the repository
2. Create a feature branch
3. Make your changes in accordance with existing coding patterns
4. Test functionality thoroughly
5. Submit a pull request with clear changes described

### Coding Standards
- Follow existing code style and structure
- Maintain compatibility with Python 3.8+
- Use descriptive function and variable names
- Include meaningful comments and docstrings

## Support

For issues or questions:
- Check troubleshooting section first
- Verify system requirements and permissions
- Test on a known working platform if available
- Create an issue on the GitHub repository with detailed error information

## License

See the LICENSE file for licensing information.