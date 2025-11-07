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

### Raspberry Pi Setup:
For Raspberry Pi 3 with Bookworm OS, use the installation script:
```bash
cd rpi3_bookworm
./rpi_install_bookworm.sh
```
This will install dependencies and set up a systemd service to start the Flask GUI automatically on boot.

To start manually (after installation):
```bash
cd rpi3_bookworm
./start_comparatron.sh
```
This will start the Flask server and optionally open the browser if on a desktop system.

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
- Completion notes
- Original README with usage instructions
