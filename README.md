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
- `main_refactored.py` - Main application (refactored)
- `camera_manager.py` - Camera selection and management
- `serial_comm.py` - Serial communication with CNC machine
- `machine_control.py` - Machine control functions
- `dxf_handler.py` - DXF file creation and export  
- `gui_handler.py` - GUI interface management
- `validate_optimization.py` - Validation script
- `validate_git.sh` - Git validation script

### Dependencies:
Install required dependencies before running:
```bash
cd dependencies/
chmod +x install_dependencies.sh
./install_dependencies.sh
```

### For Fedora Installation:
For fresh Fedora systems, use the specific installation scripts:
```bash
cd dependencies/
chmod +x fedora_install_simple.sh
./fedora_install_simple.sh
```

### Running the Application:
```bash
python3 main_refactored.py
```

## Documentation:
All documentation is located in the `documentation/` folder including:
- Project roadmap and optimization summary
- Windows executable creation guide
- Completion notes
- Original README with usage instructions