#!/bin/bash

# Comparatron Universal Installation Script
# Automatically detects system type and installs appropriate dependencies
# Also can optionally set up auto-start service for Raspberry Pi systems

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Universal Installation ===${NC}"

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
        # Try to install with libilmbase-dev and libopenexr-dev, which are the more compatible versions on Debian
        $SUDO apt install -y python3 python3-pip python3-dev python3-venv build-essential libatlas-base-dev libhdf5-dev libhdf5-103 libilmbase-dev libopenexr-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev libatlas3-base || {
            # If that fails due to conflicts, try to skip the problematic packages
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
    
    # Create and activate virtual environment
    echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
    python3 -m venv comparatron_env
    source comparatron_env/bin/activate

    # Upgrade pip
    echo -e "${YELLOW}Upgrading pip...${NC}"
    python3 -m pip install --upgrade pip

    # Install Python packages - use piwheels for ARM/RPi if available
    echo -e "${YELLOW}Installing required Python packages...${NC}"

    # Install packages that have ARM-compatible versions first
    python3 -m pip install --prefer-binary numpy

    # Install OpenCV with timeout and ARM-specific optimizations
    echo -e "${YELLOW}Installing OpenCV headless version (optimized for ARM if needed)...${NC}"
    if [[ "$DISTRO_TYPE" == "raspberry_pi" ]]; then
        # For RPi use piwheels specifically
        python3 -m pip install --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary opencv-python-headless || {
            echo -e "${YELLOW}OpenCV installation taking too long or failed, continuing...${NC}"
        }
    else
        python3 -m pip install --prefer-binary opencv-python-headless || {
            echo -e "${YELLOW}OpenCV installation taking too long or failed, continuing...${NC}"
        }
    fi

    # Install remaining packages
    if [[ "$DISTRO_TYPE" == "raspberry_pi" ]]; then
        # Use piwheels for ARM packages on RPi
        python3 -m pip install --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary flask pillow pyserial ezdxf pyinstaller
    else
        python3 -m pip install --prefer-binary flask pillow pyserial ezdxf pyinstaller
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
        $SUDO dnf install -y python3 python3-pip python3-dev python3-venv build-essential libatlas-base-dev libhdf5-dev libhdf5-103 libilmbase-dev libopenexr-dev libgstreamer1.0-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff5-dev libjasper-dev gcc gcc-c++ libatlas3-base
    fi
    
    # Create and activate virtual environment
    echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
    python3 -m venv comparatron_env
    source comparatron_env/bin/activate
    
    # Upgrade pip
    echo -e "${YELLOW}Upgrading pip...${NC}"
    python3 -m pip install --upgrade pip
    
    # Install Python packages
    echo -e "${YELLOW}Installing required Python packages...${NC}"
    python3 -m pip install --prefer-binary numpy flask pillow pyserial ezdxf opencv-python-headless pyinstaller
}

# Generic installation (for any system)
install_generic() {
    echo -e "${YELLOW}Installing for generic system...${NC}"
    
    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is not installed.${NC}"
        exit 1
    fi
    
    # Create and activate virtual environment
    echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
    python3 -m venv comparatron_env
    source comparatron_env/bin/activate
    
    # Upgrade pip
    echo -e "${YELLOW}Upgrading pip...${NC}"
    python3 -m pip install --upgrade pip
    
    # Install Python packages only (assumes system dependencies are already satisfied)
    echo -e "${YELLOW}Installing required Python packages...${NC}"
    python3 -m pip install --prefer-binary numpy flask pillow pyserial ezdxf opencv-python-headless pyinstaller
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
    else
        echo -e "${YELLOW}Service setup only performed on Raspberry Pi systems${NC}"
    fi
}

# Main installation process
detect_system

case "$DISTRO_TYPE" in
    "raspberry_pi")
        install_debian
        setup_service
        ;;
    "debian")
        install_debian
        ;;
    "fedora")
        install_fedora
        ;;
    *)
        install_generic
        ;;
esac

# Test the installation
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

echo -e "${GREEN}=== Installation completed ===${NC}"
echo -e "${GREEN}To use Comparatron:${NC}"
echo -e "${GREEN}1. Make sure the Comparatron folder is in your home directory as '/home/$USER/comparatron-optimised'${NC}"
echo -e "${GREEN}2. Run: source ~/comparatron_env/bin/activate && python3 ~/comparatron-optimised/main.py${NC}"
echo -e "${GREEN}3. Access the interface at: http://localhost:5001${NC}"
echo -e "${GREEN}${NC}"

if [ "$DISTRO_TYPE" = "raspberry_pi" ]; then
    echo -e "${GREEN}4. On Raspberry Pi, the web interface will automatically start on boot at: http://[RPI_IP]:5001${NC}"
    echo -e "${GREEN}5. To manually restart service: sudo systemctl restart comparatron${NC}"
fi

echo -e "${GREEN}${NC}"
echo -e "${GREEN}Note: After adding to video group (on RPi), log out and log back in to access cameras.${NC}"
echo -e "${GREEN}The main Comparatron interface is Flask-based (web interface).${NC}"