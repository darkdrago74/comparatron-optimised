#!/bin/bash

# Comparatron Universal Installation Script (Simplified with Recombination)
# Automatically detects system type and installs appropriate dependencies
# Can recombine virtual environment from chunks if available

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Universal Installation (Simplified) ===${NC}"

# Function to setup virtual environment
setup_venv() {
    echo -e "${YELLOW}Setting up Python virtual environment...${NC}"

    # Check if virtual environment exists in parent directory
    if [ -d "../comparatron_env" ]; then
        echo -e "${GREEN}Virtual environment already exists in parent directory${NC}"
        source ../comparatron_env/bin/activate
    # Check if we have venv_splits directory with the main archive
    elif [ -d "venv_splits" ] && [ -f "venv_splits/comparatron_env_main.tar.gz" ]; then
        echo -e "${YELLOW}Found chunked virtual environment, recombining...${NC}"

        # Extract the main tar.gz file to create the virtual environment
        echo -e "${YELLOW}Extracting virtual environment from archive...${NC}"
        cd ..
        if tar -xzf "dependencies/venv_splits/comparatron_env_main.tar.gz"; then
            # Verify and activate
            if [ -d "comparatron_env" ]; then
                echo -e "${GREEN}Virtual environment successfully recombined!${NC}"
                source comparatron_env/bin/activate
                chmod +x comparatron_env/bin/activate
            else
                echo -e "${RED}Error: Failed to extract virtual environment - extracted directory not found${NC}"
                python3 -m venv comparatron_env
                source comparatron_env/bin/activate
            fi
        else
            echo -e "${RED}Error: Failed to extract virtual environment archive${NC}"
            python3 -m venv comparatron_env
            source comparatron_env/bin/activate
        fi
        cd dependencies
    # If there are chunk files but no combined archive, try recombining
    elif [ -d "venv_splits" ] && [ -f "venv_splits/comparatron_env_part_aa" ]; then
        echo -e "${YELLOW}Found chunked virtual environment files, recombining...${NC}"

        # Combine all chunk files to create the main archive
        cd venv_splits
        if cat comparatron_env_part_* > ../comparatron_env_main.tar.gz; then
            cd ..
            # Extract the recombined archive to parent directory
            echo -e "${YELLOW}Extracting virtual environment from recombined archive...${NC}"
            cd ..
            if tar -xzf "dependencies/comparatron_env_main.tar.gz"; then
                # Verify extraction and activate
                if [ -d "comparatron_env" ]; then
                    echo -e "${GREEN}Virtual environment successfully recombined!${NC}"
                    source comparatron_env/bin/activate
                    chmod +x comparatron_env/bin/activate
                else
                    echo -e "${RED}Error: Failed to extract virtual environment - extracted directory not found${NC}"
                    python3 -m venv comparatron_env
                    source comparatron_env/bin/activate
                fi
            else
                echo -e "${RED}Error: Failed to extract virtual environment from recombined archive${NC}"
                python3 -m venv comparatron_env
                source comparatron_env/bin/activate
            fi
        else
            echo -e "${RED}Error: Failed to recombine virtual environment splits${NC}"
            python3 -m venv comparatron_env
            source comparatron_env/bin/activate
        fi
        cd dependencies
    # If no venv exists and no splits exist, show error
    else
        echo -e "${RED}Error: Neither virtual environment nor split files found${NC}"
        echo -e "${YELLOW}Expected to find either: ../comparatron_env directory OR${NC}"
        echo -e "${YELLOW}  - dependencies/venv_splits/comparatron_env_main.tar.gz OR${NC}"
        echo -e "${YELLOW}  - dependencies/venv_splits/comparatron_env_part_* files${NC}"
        echo -e "${RED}Please run the split_venv.sh script first to create the split files${NC}"
        exit 1
    fi
}

# Detect the operating system
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        ID_LIKE=$ID_LIKE
    else
        OS=$(uname -s)
        VER=$(uname -r)
        ID_LIKE=""
    fi
    
    echo -e "${YELLOW}Detected OS: $OS${NC}"
    
    # Check if this is Raspbian/Debian-based system (especially RPi)
    if [[ "$OS" == *"Raspbian"* ]] || [[ "$OS" == *"Debian GNU/Linux"* ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        if grep -q "Raspberry\|raspberrypi\|rpi" /proc/cpuinfo 2>/dev/null || 
           [ -f "/opt/vc/bin/vcgencmd" ] || 
           grep -q "Raspberry\|BCM" /proc/cpuinfo 2>/dev/null; then
            DISTRO_TYPE="raspberry_pi"
        else
            DISTRO_TYPE="debian"
        fi
    elif [[ "$OS" == *"Fedora"* ]] || [[ -f /etc/fedora-release ]]; then
        DISTRO_TYPE="fedora"
    else
        # Try to determine based on package manager
        if command -v dnf &> /dev/null; then
            DISTRO_TYPE="fedora"
        elif command -v apt-get &> /dev/null; then
            DISTRO_TYPE="debian"
        else
            DISTRO_TYPE="generic"
        fi
    fi
    
    echo -e "${YELLOW}Detected system type: $DISTRO_TYPE${NC}"
}

# Install for Debian-based systems (including RPi)
install_debian() {
    echo -e "${YELLOW}Installing for Debian-based system...${NC}"
    
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        SUDO=""
        echo -e "${RED}Sudo not available, some operations may fail${NC}"
    fi
    
    # Update package list
    echo -e "${YELLOW}Updating package list...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO apt update -y
    fi
    
    # Install system dependencies - avoid conflicting packages
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO apt install -y python3 python3-pip python3-dev python3-venv build-essential libatlas-base-dev libhdf5-dev libhdf5-103 libilmbase-dev libopenexr-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev libatlas3-base || {
            echo -e "${YELLOW}Attempting to resolve dependency conflicts...${NC}"
            $SUDO apt install -y python3 python3-pip python3-dev python3-venv build-essential libatlas-base-dev libhdf5-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev || {
                echo -e "${YELLOW}Continuing without some optional dependencies...${NC}"
            }
        }
    else
        # Without sudo, check if the required python components exist
        if ! command -v python3 &> /dev/null; then
            echo -e "${RED}Error: python3 is not available and no sudo access${NC}"
            exit 1
        fi
    fi
}

# Install for Fedora-based systems
install_fedora() {
    echo -e "${YELLOW}Installing for Fedora system...${NC}"
    
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        SUDO=""
        echo -e "${RED}Sudo not available, some operations may fail${NC}"
    fi
    
    # Update package list
    echo -e "${YELLOW}Updating package list...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO dnf update -y
    fi
    
    # Install system dependencies
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    if [ -n "$SUDO" ]; then
        $SUDO dnf install -y python3 python3-pip python3-devel python3-venv build-essential libatlas-base-dev libhdf5-dev libhdf5-103 libilmbase-dev libopenexr-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev gcc gcc-c++ libatlas3-base
    fi
}

# Generic installation (for any system)
install_generic() {
    echo -e "${YELLOW}Installing for generic system...${NC}"
    
    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is not installed.${NC}"
        exit 1
    fi
}

# Set up auto-start service (specific to Raspberry Pi)
setup_service() {
    if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
        echo -e "${YELLOW}Setting up auto-start service for Raspberry Pi...${NC}"
        
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
        else
            echo -e "${YELLOW}Sudo not available, skipping systemd service setup${NC}"
            return
        fi
        
        # Create a systemd service file
        SERVICE_FILE="/etc/systemd/system/comparatron.service"
        SERVICE_CONTENT="[Unit]
Description=Comparatron Flask GUI
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/comparatron-optimised
Environment=PATH=/home/$USER/comparatron_env/bin
ExecStart=/home/$USER/comparatron_env/bin/python3 /home/$USER/comparatron-optimised/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

        echo "$SERVICE_CONTENT" | $SUDO tee "$SERVICE_FILE"
        $SUDO systemctl daemon-reload
        $SUDO systemctl enable comparatron.service
        echo -e "${GREEN}Comparatron service enabled to start on boot${NC}"
        
        # Add user to video group for camera access
        $SUDO usermod -a -G video $USER
        echo -e "${GREEN}User added to video group for camera access${NC}"

        # Add user to dialout group for serial port access (needed for Arduino/GRBL communication)
        $SUDO usermod -a -G dialout $USER
        echo -e "${GREEN}User added to dialout group for serial port access${NC}"
        echo -e "${YELLOW}Note: You may need to log out and log back in, or reboot, for the group changes to take effect${NC}"
    else
        # For non-Raspberry Pi systems, add both video and dialout groups
        if command -v sudo &> /dev/null; then
            $SUDO usermod -a -G video $USER
            echo -e "${GREEN}User added to video group for camera access${NC}"
            $SUDO usermod -a -G dialout $USER
            echo -e "${GREEN}User added to dialout group for serial port access${NC}"
            echo -e "${YELLOW}Note: You may need to log out and log back in, or reboot, for the group changes to take effect${NC}"
        fi
    fi
}

# Test the installation
test_installation() {
    echo -e "${YELLOW}Testing the installation...${NC}"

    for pkg in numpy flask pillow pyserial ezdxf cv2; do
        if [ "$pkg" = "cv2" ]; then
            IMP="cv2 as cv" 
        elif [ "$pkg" = "pillow" ]; then
            IMP="PIL as Image"
        elif [ "$pkg" = "pyserial" ]; then
            IMP="serial"
        else
            IMP="$pkg"
        fi
        
        if python3 -c "import $IMP" &> /dev/null; then
            echo -e "${GREEN}✓ $pkg working${NC}"
        else
            # For OpenCV, it might be acceptable that it's not available during installation (takes too long)
            if [ "$pkg" = "cv2" ]; then
                echo -e "${YELLOW}? $pkg may not be available (can take long time to install on RPi)${NC}"
            else
                echo -e "${RED}✗ $pkg not working${NC}"
            fi
        fi
    done
}

# Main installation process
detect_system

# Call appropriate install function based on detected system
case "$DISTRO_TYPE" in
    "raspberry_pi"|"debian")
        install_debian
        ;;
    "fedora")
        install_fedora
        ;;
    *)
        install_generic
        ;;
esac

# Set up virtual environment with recombination support
setup_venv

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
../comparatron_env/bin/python -m pip install --upgrade pip

# Install Python packages - use piwheels for ARM/RPi if available
echo -e "${YELLOW}Installing required Python packages...${NC}"

# Install packages that have ARM-compatible versions first
../comparatron_env/bin/python -m pip install --prefer-binary numpy

# Install OpenCV with timeout and ARM-specific optimizations
echo -e "${YELLOW}Installing OpenCV headless version (optimized for ARM if needed)...${NC}"
if [[ "$DISTRO_TYPE" == "raspberry_pi" ]]; then
    # For RPi use piwheels specifically
    timeout 120 ../comparatron_env/bin/python -m pip install --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary opencv-python-headless || {
        echo -e "${YELLOW}OpenCV installation taking too long or failed, continuing...${NC}"
    }
else
    timeout 120 ../comparatron_env/bin/python -m pip install --prefer-binary opencv-python-headless || {
        echo -e "${YELLOW}OpenCV installation taking too long or failed, continuing...${NC}"
    }
fi

# Install remaining packages
if [[ "$DISTRO_TYPE" == "raspberry_pi" ]]; then
    # Use piwheels for ARM packages on RPi
    ../comparatron_env/bin/python -m pip install --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary flask pillow pyserial ezdxf pyinstaller
else
    ../comparatron_env/bin/python -m pip install --prefer-binary flask pillow pyserial ezdxf pyinstaller
fi

# Create a temporary requirements file in case of issues
cat > requirements.txt << EOF
numpy
flask
pillow
pyserial
ezdxf
opencv-python-headless
pyinstaller
EOF

# Install from requirements to handle any remaining dependency issues with ARM-optimized packages
timeout 30 ../comparatron_env/bin/python -m pip install --prefer-binary -r requirements.txt || echo -e "${YELLOW}Some packages may have failed but continuing...${NC}"

# Clean up
rm requirements.txt

# Test the installation
test_installation

echo -e "${GREEN}=== Installation completed ===${NC}"
echo -e "${GREEN}To use Comparatron:${NC}"
echo -e "${GREEN}1. Make sure the Comparatron folder is in your home directory as '/home/$USER/comparatron-optimised'${NC}"
echo -e "${GREEN}2. The web interface will be available at: http://localhost:5001${NC}"
echo -e "${GREEN}3. To manually start: cd .. && source comparatron_env/bin/activate && python3 main.py${NC}"
echo -e "${GREEN}${NC}"

if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
    echo -e "${GREEN}4. On Raspberry Pi, the web interface will automatically start on boot at: http://[RPI_IP]:5001${NC}"
    echo -e "${GREEN}5. To manually restart service: sudo systemctl restart comparatron${NC}"
fi

echo -e "${GREEN}${NC}"
echo -e "${YELLOW}IMPORTANT:${NC}"
echo -e "${YELLOW}  - You have been added to the dialout group for serial port access${NC}"
echo -e "${YELLOW}  - You need to logout and login again for the group changes to take effect${NC}"
echo -e "${YELLOW}  - After logging in, the Arduino/GRBL shield will be accessible via serial${NC}"
echo -e "${YELLOW}  - The main Comparatron interface is Flask-based (web interface).${NC}"