# LaserWeb4 Setup

This folder contains the installation script to set up LaserWeb4 on a Raspberry Pi.

## About LaserWeb4

LaserWeb4 is a web-based interface for controlling laser cutters and CNC machines. It provides a browser-based GUI for controlling GRBL-based machines and offers features like:
- G-code visualization and simulation
- Real-time machine control
- Camera integration for positioning
- File import and conversion
- Multiple controller support

## Node.js Version Recommendation

For optimal serial communication with Arduino/GRBL controllers, LaserWeb4 works best with **Node.js v18.x**. On systems with newer Node.js versions (v20+), native module compatibility issues may limit direct serial communication functionality.

### Installing Node.js v18.x on Raspberry Pi:

```bash
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

## Installation

To install LaserWeb4 on your Raspberry Pi:

```bash
./install_laserweb4_rpi.sh
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
- Primary access: `http://localhost:8000`
- Network access: `http://[YOUR_COMPUTER_IP]:8000`

## Configuration

The installation creates a default configuration file at `~/LaserWeb/config.json`.
You can customize this file to adjust ports, plugins, and other settings.

## Running Alongside Comparatron

LaserWeb4 runs on port 8000 by default, while Comparatron runs on port 5001, so both can run simultaneously on the same Raspberry Pi.

## Notes

- The installation script is optimized for Raspberry Pi OS Bookworm
- Auto-start service will launch LaserWeb4 on boot
- Serial access requires user to be in dialout group (set up during installation)
- For reliable CNC control, Comparatron interface (port 5001) provides better serial communication