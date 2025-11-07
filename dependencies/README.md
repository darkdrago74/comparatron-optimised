# Comparatron Dependencies and Setup

This folder contains the necessary scripts and information to set up Comparatron on different systems.

## Important Steps Before Running

### For Fedora Systems:
1. **Install Fedora Installation Script**: Use the simplified Fedora installation script for a fresh Fedora installation.

   - `fedora_install_simple.sh` - Comprehensive installation for Fedora systems

2. **Run the Installation Script**:
   ```bash
   chmod +x fedora_install_simple.sh
   ./fedora_install_simple.sh
   ```

3. **Camera Access**: After installation, you may need to log out and log back in to access camera devices, or run:
   ```bash
   newgrp video
   ```

### For Other Systems:
1. **Install Dependencies**: Use the generic installation script adapted for your distribution
   ```bash
   chmod +x install_dependencies.sh
   ./install_dependencies.sh
   ```

### After Dependencies Installation:
1. Clone or place the Comparatron source files in your desired directory
2. Run the application with: `python3 main.py` (primary Flask interface)

Alternative interfaces:
- Flask Web Interface: `python3 main.py` (primary)

## Requirements
- Python 3.7 or higher
- Camera access permissions
- Serial port access for CNC machine connection