# Raspberry Pi 3 Bookworm Setup

This folder contains all necessary files to set up Comparatron on a Raspberry Pi 3 running Bookworm OS.

## Installation

To install Comparatron on your Raspberry Pi:

```bash
./rpi_install_bookworm.sh
```

This will:
- Install all required dependencies
- Create a Python virtual environment
- Set up systemd service to auto-start on boot
- Add the current user to the video group for camera access

## Manual Start

To start Comparatron manually without using the auto-start service:

```bash
./start_comparatron.sh
```

## Accessing the Interface

After installation, access the web interface at:
- `http://[RASPBERRY_PI_IP]:5001`

## Requirements

- Raspberry Pi 3 or newer
- Raspberry Pi OS with Bookworm
- USB camera connected
- Network access for remote control

## Notes

- The installation script is optimized for ARM architecture
- Uses headless OpenCV for better performance on RPi
- Auto-start service will launch the Flask GUI on boot
- Camera access requires user to be in video group (set up during installation)