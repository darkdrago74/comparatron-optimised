#!/bin/bash

# Comparatron Generic Installation Script with Virtual Environment Recombination
# For systems where automatic system detection may not be reliable
# Can recombine virtual environment from chunks if available

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comparatron Generic Installation (with Recombination) ===${NC}"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed.${NC}"
    exit 1
fi

# Function to setup virtual environment
setup_venv() {
    echo -e "${YELLOW}Setting up Python virtual environment...${NC}"

    # Check if virtual environment exists in parent directory
    if [ -d "../comparatron_env" ]; then
        echo -e "${GREEN}Virtual environment already exists in parent directory${NC}"
        # Explicitly activate the virtual environment
        source ../comparatron_env/bin/activate
        echo -e "${YELLOW}Virtual environment activated: $(which python)${NC}"
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
                echo -e "${YELLOW}Virtual environment activated: $(which python)${NC}"
            else
                echo -e "${RED}Error: Failed to extract virtual environment - extracted directory not found${NC}"
                python3 -m venv comparatron_env
                source comparatron_env/bin/activate
                echo -e "${YELLOW}New virtual environment created and activated: $(which python)${NC}"
            fi
        else
            echo -e "${RED}Error: Failed to extract virtual environment archive${NC}"
            python3 -m venv comparatron_env
            source comparatron_env/bin/activate
            echo -e "${YELLOW}New virtual environment created and activated: $(which python)${NC}"
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
                    echo -e "${YELLOW}Virtual environment activated: $(which python)${NC}"
                else
                    echo -e "${RED}Error: Failed to extract virtual environment - extracted directory not found${NC}"
                    python3 -m venv comparatron_env
                    source comparatron_env/bin/activate
                    echo -e "${YELLOW}New virtual environment created and activated: $(which python)${NC}"
                fi
            else
                echo -e "${RED}Error: Failed to extract virtual environment from recombined archive${NC}"
                python3 -m venv comparatron_env
                source comparatron_env/bin/activate
                echo -e "${YELLOW}New virtual environment created and activated: $(which python)${NC}"
            fi
        else
            echo -e "${RED}Error: Failed to recombine virtual environment splits${NC}"
            python3 -m venv comparatron_env
            source comparatron_env/bin/activate
            echo -e "${YELLOW}New virtual environment created and activated: $(which python)${NC}"
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

# Set up virtual environment with recombination capability
setup_venv

# Upgrade pip - use the virtual environment's python explicitly
echo -e "${YELLOW}Upgrading pip...${NC}"
if [ -f "../comparatron_env/bin/python" ]; then
    ../comparatron_env/bin/python -m pip install --break-system-packages --upgrade pip
else
    python -m pip install --break-system-packages --upgrade pip
fi

# Ensure pip is available in virtual environment
if [ -f "../comparatron_env/bin/pip" ]; then
    PIP_CMD="../comparatron_env/bin/pip"
elif [ -f "../comparatron_env/bin/python" ]; then
    PIP_CMD="../comparatron_env/bin/python -m pip"
else
    PIP_CMD="python -m pip"
fi

# Install required packages
echo -e "${YELLOW}Installing required Python packages...${NC}"

# Install packages that have ARM-compatible versions first
$PIP_CMD install --break-system-packages --prefer-binary numpy

# Install OpenCV with timeout - try piwheels for ARM compatibility
echo -e "${YELLOW}Installing OpenCV headless version...${NC}"
DISTRO_TYPE="unknown"  # Determine distro type for proper piwheels usage
if [ -f "/etc/os-release" ]; then
    . /etc/os-release
    if [[ "$ID" == *"raspbian"* ]] || [[ -f "/opt/vc/bin/vcgencmd" ]]; then
        DISTRO_TYPE="raspberry_pi"
    fi
fi

if [[ "$DISTRO_TYPE" == "raspberry_pi" ]]; then
    timeout 120 $PIP_CMD install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary opencv-python-headless || {
        echo -e "${YELLOW}OpenCV installation from piwheels failed, trying standard installation...${NC}"
        timeout 120 $PIP_CMD install --break-system-packages --prefer-binary opencv-python-headless || {
            echo -e "${YELLOW}OpenCV installation taking too long or failed, continuing...${NC}"
            echo -e "${YELLOW}Note: CV2 may be missing, but other functionality will work.${NC}"
        }
    }
else
    timeout 120 $PIP_CMD install --break-system-packages --prefer-binary opencv-python-headless || {
        echo -e "${YELLOW}OpenCV installation taking too long or failed, continuing...${NC}"
    }
fi

# Install remaining packages
if [[ "$DISTRO_TYPE" == "raspberry_pi" ]]; then
    $PIP_CMD install --break-system-packages --index-url https://www.piwheels.org/simple/ --trusted-host www.piwheels.org --prefer-binary flask pillow pyserial ezdxf pyinstaller
else
    $PIP_CMD install --break-system-packages --prefer-binary flask pillow pyserial ezdxf pyinstaller
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

# Install from requirements to handle any remaining dependency issues
timeout 30 pip install --prefer-binary -r requirements.txt || echo -e "${YELLOW}Some packages may have failed but continuing...${NC}"

# Clean up
rm requirements.txt

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
            echo -e "${YELLOW}? $pkg may not be available (can take long time to install)${NC}"
        else
            echo -e "${RED}✗ $pkg not working${NC}"
        fi
    fi
done

# Set up auto-start service and add user to groups if needed
if command -v sudo &> /dev/null; then
    SUDO="sudo"
else
    SUDO=""
fi

# Add user to both video and dialout groups for camera and serial access
if [ -n "$SUDO" ]; then
    $SUDO usermod -a -G video $USER
    echo -e "${GREEN}User added to video group for camera access${NC}"
    $SUDO usermod -a -G dialout $USER
    echo -e "${GREEN}User added to dialout group for serial port access${NC}"
fi

echo -e "${GREEN}=== Installation completed ===${NC}"
echo -e "${GREEN}To use Comparatron:${NC}"
echo -e "${GREEN}1. Make sure the Comparatron folder is in your home directory as '/home/$USER/comparatron-optimised'${NC}"
echo -e "${GREEN}2. The web interface will be available at: http://localhost:5001${NC}"
echo -e "${GREEN}3. To manually start: cd .. && source comparatron_env/bin/activate && python3 main.py${NC}"
echo -e "${GREEN}${NC}"

echo -e "${YELLOW}IMPORTANT:${NC}"
echo -e "${YELLOW}  - You have been added to the video group for camera access${NC}"
echo -e "${YELLOW}  - You have been added to the dialout group for serial port access${NC}"
echo -e "${YELLOW}  - You need to logout and login again for the group changes to take effect${NC}"
echo -e "${YELLOW}  - After logging in, cameras and the Arduino/GRBL shield will be accessible${NC}"
echo -e "${YELLOW}  - The main Comparatron interface is Flask-based (web interface).${NC}"