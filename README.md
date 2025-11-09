# Comparatron - Digital Optical Comparator

Improvement with Qwen3-coder

```bash
git clone https://github.com/darkdrago74/comparatron-optimised.git
```

## Project Structure

This project has been optimized and reorganized into the following structure:

### Folders:
- `dependencies/` - Installation scripts and setup instructions
- `documentation/` - All documentation files (MD and TXT)
- Root directory - Core Python modules and main application

### Core Files:
- `main.py` - Main Flask-based application (primary)
- `camera_manager.py` - Camera selection and management
- `serial_comm.py` - Serial communication with CNC machine
- `machine_control.py` - Machine control functions
- `dxf_handler.py` - DXF file creation and export  
- `gui_flask.py` - Flask GUI interface management
- `validate_optimization.py` - Validation script

### Dependencies:
Install required dependencies before running:
```bash
cd dependencies/
chmod +x fedora_install_simple.sh
./fedora_install_simple.sh
```

### For Fedora Installation:
For fresh Fedora systems, use the specific installation scripts:
```bash
cd dependencies/
chmod +x fedora_install_simple.sh
./fedora_install_simple.sh
```

### Running the Application:

#### For Web Interface (Primary - Flask):
```bash
python3 main.py
```
The web interface will be available at http://localhost:5001

#### For Desktop GUI (Backup - DearPyGUI):
```bash
python3 main_dearpygui_backup.py
```

### Uninstalling Everything:

To completely remove Comparatron and LaserWeb4 installations:

```bash
cd dependencies/
./uninstall.sh
```

This will remove all services, virtual environments, and installed packages related to both Comparatron and LaserWeb4.

## Prerequisites

Before installing Comparatron, ensure you have these system dependencies installed:

### For Fedora Systems:
```bash
sudo dnf install python3 python3-pip python3-devel git nodejs npm nginx
```

### For Raspberry Pi (Bookworm):
```bash
sudo apt install python3 python3-pip python3-dev git nodejs npm nginx
```

### Camera Access on Linux/Fedora:
If cameras are not detected, you may need to add your user to the video group:
```bash
sudo usermod -a -G video $USER
```
Then log out and log back in to apply the permissions. After this, your cameras should be accessible to the application.

### Web Interface Features:
- Accessible from any device on the same network
- Responsive design works on desktop and mobile
- Real-time camera feed
- Full machine control interface
- Point recording and DXF export

### For Raspberry Pi Setup:
For Raspberry Pi systems with Bookworm OS, the universal installer automatically detects and configures appropriately:
```bash
cd dependencies/
chmod +x install_dependencies_universal.sh
./install_dependencies_universal.sh
```
If detected as a Raspberry Pi, this will install dependencies and optionally set up a systemd service to auto-start the Flask GUI on boot.

To start manually (after installation):
```bash
source ~/comparatron_env/bin/activate
python3 ~/comparatron-optimised/main.py
```
This will start the Flask server and the web interface will be accessible at the address shown in the terminal.

### Running with LaserWeb4:
LaserWeb4 can run simultaneously on the same Raspberry Pi. It's available in the laserweb4 folder:
```bash
cd laserweb4
./install_laserweb4.sh
```
- Comparatron runs on port 5001: `http://[RPI_IP]:5001`
- LaserWeb4 runs on port 8000: `http://[RPI_IP]:8000`
- Both can run simultaneously on the same Raspberry Pi

## Documentation:
All documentation is located in the `documentation/` folder including:
- Project roadmap and optimization summary
- Windows executable creation guide
- GitHub setup guide for large projects with Git LFS
- Completion notes
- Original README with usage instructions

### Universal Installation (Recommended):
For automatic system detection (Fedora, Raspberry Pi, or other Linux systems):
```bash
cd dependencies/
chmod +x install_dependencies_universal.sh
./install_dependencies_universal.sh
```
This script automatically detects your system type and installs the appropriate dependencies.

