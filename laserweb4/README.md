# LaserWeb4 Setup

This folder contains the installation script to set up LaserWeb4 on a Raspberry Pi.

## About LaserWeb4

LaserWeb4 is a web-based interface for controlling laser cutters and CNC machines. It provides a browser-based GUI for controlling GRBL-based machines and offers features like:
- G-code visualization and simulation
- Real-time machine control
- Camera integration for positioning
- File import and conversion
- Multiple controller support

## Installation

To install LaserWeb4 on your Raspberry Pi:

```bash
./install_laserweb4.sh
```

This will:
- Install all required dependencies (Node.js, npm, git, etc.)
- Clone the LaserWeb4 repository
- Install Node.js packages
- Build the application
- Set up auto-start service to run on boot
- Add the current user to the dialout group for serial access

## Accessing the Interface

After installation, access the web interface at:
- Direct access: `http://[RASPBERRY_PI_IP]:8000`
- Via nginx proxy: `http://[RASPBERRY_PI_IP]:8080` (if nginx configuration was selected)

## Configuration

The installation creates a default configuration file at `~/LaserWeb/config.json`.
You can customize this file to adjust ports, plugins, and other settings.

## Running Alongside Comparatron

LaserWeb4 runs on port 8000 by default, while Comparatron runs on port 5001, so both can run simultaneously on the same Raspberry Pi.

## Notes

- The installation script is optimized for Raspberry Pi OS Bookworm
- Auto-start service will launch LaserWeb4 on boot
- Serial access requires user to be in dialout group (set up during installation)