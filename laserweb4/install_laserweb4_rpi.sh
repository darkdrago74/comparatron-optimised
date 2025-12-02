#!/bin/bash

# LaserWeb4 Installation Script for Raspberry Pi
# Follows standard LaserWeb4 installation process optimized for RPi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== LaserWeb4 Installation for Raspberry Pi ===${NC}"

# Check if Node.js and npm are installed
echo -e "${YELLOW}Checking Node.js and npm...${NC}"
if ! command -v node &> /dev/null && ! command -v nodejs &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed.${NC}"
    echo -e "${YELLOW}Please install Node.js first:${NC}"
    echo -e "${YELLOW}  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt install -y nodejs${NC}"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed.${NC}"
    echo -e "${YELLOW}Please install npm first.${NC}"
    exit 1
fi

# Show version information
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}Node.js: $NODE_VERSION${NC}"
else
    NODE_VERSION=$(nodejs --version)
    echo -e "${GREEN}Node.js: $NODE_VERSION${NC}"
fi

NPM_VERSION=$(npm --version)
echo -e "${GREEN}npm: $NPM_VERSION${NC}"

# Check if running on Raspberry Pi
if [ ! -f "/opt/vc/bin/vcgencmd" ] && ! grep -q "Raspberry\|BCM\|raspberrypi\|armv7l\|aarch64" /proc/cpuinfo; then
    echo -e "${RED}Warning: This script is intended for Raspberry Pi only.${NC}"
    echo -e "${YELLOW}Consider using install_laserweb4_generic.sh for other systems.${NC}"
fi

# Note: Skip build tools requirement for simplicity (native modules may fail but core functionality works)
echo -e "${YELLOW}Note: Build tools (make, gcc, etc.) may be needed for native modules${NC}"
echo -e "${YELLOW}If you encounter build errors, install build-essential package manually:${NC}"
echo -e "${YELLOW}  sudo apt install build-essential pkg-config libusb-1.0-0-dev${NC}"

# Install piwheels for faster ARM package installation (if available)
if command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}Configuring piwheels for faster ARM package installation...${NC}"
    pip3 install --upgrade pip
fi

# Install system dependencies required for LaserWeb4 on RPi
echo -e "${YELLOW}Installing system dependencies for Raspberry Pi...${NC}"
if command -v sudo &> /dev/null; then
    # Update package lists first
    sudo apt update -y
    # Install dependencies commonly needed for LaserWeb4 on RPi
    sudo apt install -y build-essential libusb-1.0-0-dev libudev-dev pkg-config libgtk-3-dev python3-dev python3-pip git
fi

# Create user installation directory
INSTALL_DIR="$HOME/LaserWeb"
echo -e "${YELLOW}Installing LaserWeb4 to: $INSTALL_DIR${NC}"

# Check if LaserWeb installation exists, or if we have split files to recombine
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}LaserWeb4 directory already exists${NC}"
    cd "$INSTALL_DIR"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/laserweb_splits/laserweb4_main.tar.gz" ]; then
    echo -e "${YELLOW}Found chunked LaserWeb4 installation, recombining...${NC}"

    # Extract the main tar.gz file to create the LaserWeb4 installation
    echo -e "${YELLOW}Extracting LaserWeb4 installation from archive...${NC}"
    cd "$HOME"
    if tar -xzf "$(dirname "${BASH_SOURCE[0]}")/laserweb_splits/laserweb4_main.tar.gz"; then
        # Verify extraction
        if [ -d "LaserWeb" ]; then
            echo -e "${GREEN}LaserWeb4 installation successfully recombined!${NC}"
            cd LaserWeb
        else
            echo -e "${RED}Error: Failed to extract LaserWeb4 installation - extracted directory not found${NC}"
            echo -e "${YELLOW}Falling back to repository clone...${NC}"
            git clone --depth 1 https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
            cd "$INSTALL_DIR"
        fi
    else
        echo -e "${RED}Error: Failed to extract LaserWeb4 installation archive${NC}"
        echo -e "${YELLOW}Falling back to repository clone...${NC}"
        git clone --depth 1 https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
    cd "$(dirname "${BASH_SOURCE[0]}")"  # Return to dependencies directory
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/laserweb_splits/laserweb4_part_aa" ]; then
    echo -e "${YELLOW}Found chunked LaserWeb4 files, recombining...${NC}"

    # Combine all chunk files to create the main archive
    cd "$(dirname "${BASH_SOURCE[0]}")/laserweb_splits"
    if cat laserweb4_part_* > ../laserweb4_main.tar.gz; then
        cd ..
        # Extract the recombined archive
        echo -e "${YELLOW}Extracting LaserWeb4 installation from recombined archive...${NC}"
        cd "$HOME"
        if tar -xzf "Documents/comparatron-optimised/laserweb4/laserweb4_main.tar.gz"; then
            # Verify extraction
            if [ -d "LaserWeb" ]; then
                echo -e "${GREEN}LaserWeb4 installation successfully recombined!${NC}"
                cd LaserWeb
            else
                echo -e "${RED}Error: Failed to extract LaserWeb4 installation - extracted directory not found${NC}"
                echo -e "${YELLOW}Falling back to repository clone...${NC}"
                git clone --depth 1 https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
                cd "$INSTALL_DIR"
            fi
        else
            echo -e "${RED}Error: Failed to extract LaserWeb4 installation from recombined archive${NC}"
            echo -e "${YELLOW}Falling back to repository clone...${NC}"
            git clone --depth 1 https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
            cd "$INSTALL_DIR"
        fi
    else
        echo -e "${RED}Error: Failed to recombine LaserWeb4 installation splits${NC}"
        echo -e "${YELLOW}Falling back to repository clone...${NC}"
        git clone --depth 1 https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
else
    # Default behavior - clone from GitHub (follows standard installation)
    echo -e "${YELLOW}Cloning LaserWeb4 repository (standard installation)...${NC}"
    git clone --depth 1 https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Initialize and update submodules
echo -e "${YELLOW}Initializing and updating git submodules...${NC}"
git submodule init --quiet
git submodule update --quiet --recursive

# Check Node.js version compatibility
echo -e "${YELLOW}Checking Node.js version compatibility...${NC}"
NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -gt 18 ]; then
    echo -e "${YELLOW}Node.js version is newer than recommended (v18.x)${NC}"
    echo -e "${YELLOW}This may cause compatibility issues with native modules like serialport${NC}"
fi

# Install Node.js dependencies with compatibility fixes
echo -e "${YELLOW}Installing Node.js dependencies (this may take a while)...${NC}"

# Install with production flags and skip optional dependencies that may cause issues
# Use --ignore-scripts to avoid compilation of native modules that are incompatible with Node.js v24.x
npm install --production --no-optional --prefer-offline --no-audit --no-fund --legacy-peer-deps --ignore-scripts || {
    echo -e "${YELLOW}Standard installation failed, trying with additional compatibility flags...${NC}"
    npm install --production --no-optional --prefer-offline --no-audit --no-fund --legacy-peer-deps --ignore-scripts --engine-strict=false || {
        echo -e "${YELLOW}Attempting installation without native module building (last resort)...${NC}"
        npm install --production --no-optional --no-audit --no-fund --legacy-peer-deps --ignore-scripts --no-bin-links --force
    }
}

# Install npm-run-all which is required for the start script (main issue fix)
echo -e "${YELLOW}Installing npm-run-all which is required for running LaserWeb4...${NC}"
npm install --save-dev npm-run-all --no-optional --legacy-peer-deps --ignore-scripts || {
    # If dev install fails, try global 
    if [ -n "$SUDO" ]; then
        $SUDO npm install -g npm-run-all --no-optional --legacy-peer-deps --ignore-scripts || {
            echo -e "${RED}Error: Could not install npm-run-all - this will cause the start script to fail${NC}"
            exit 1
        }
    else
        npm install -g npm-run-all --no-optional --legacy-peer-deps --ignore-scripts || {
            echo -e "${RED}Error: Could not install npm-run-all - this will cause the start script to fail${NC}"
            exit 1
        }
    fi
}

# Install lw.comm-server without native module requirements for Node.js v24.x compatibility
echo -e "${YELLOW}Installing lw.comm-server with Node.js v24.x compatibility...${NC}"
npm install lw.comm-server --no-optional --legacy-peer-deps --ignore-scripts --force || {
    echo -e "${YELLOW}lw.comm-server installation failed due to native module incompatibility with Node.js v24.x${NC}"
    echo -e "${YELLOW}LaserWeb4 will run without direct Arduino/GRBL communication features${NC}"
    echo -e "${YELLOW}Use Comparatron interface for reliable CNC control instead${NC}"
}

# Set up configuration
echo -e "${YELLOW}Setting up LaserWeb4 configuration...${NC}"

CONFIG_FILE="$INSTALL_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    # Create default config file
    cat > "$CONFIG_FILE" << EOF
{
  "server": {
    "port": 8000,
    "host": "0.0.0.0",
    "ssl": false,
    "socketIoPath": "/socket.io"
  },
  "app": {
    "title": "LaserWeb4 - CNC Control",
    "debug": false
  },
  "defaults": {
    "language": "en",
    "theme": "dark"
  },
  "plugins": [
    "lw.comm",
    "lw.gcode",
    "lw.grbl",
    "lw.cnc",
    "lw.dsp",
    "lw.laser",
    "lw.camera",
    "lw.spindle",
    "lw.pins",
    "lw.macros",
    "lw.probe"
  ]
}
EOF
    echo -e "${GREEN}Default configuration created${NC}"
else
    echo -e "${YELLOW}Configuration file already exists, keeping existing file${NC}"
fi

# Create a start script in the home directory
START_SCRIPT="$HOME/start_laserweb.sh"
cat > "$START_SCRIPT" << 'EOF'
#!/bin/bash
# LaserWeb4 Start Script
echo "Starting LaserWeb4..."
echo "Access the interface at: http://localhost:8000"
echo "Access from other devices: http://[YOUR_COMPUTER_IP]:8000"

cd $HOME/LaserWeb
echo "Current directory: $(pwd)"
echo "LaserWeb4 server is starting..."

# Start LaserWeb4 server
npm start

echo "LaserWeb4 server stopped."
EOF

chmod +x "$START_SCRIPT"
echo -e "${GREEN}Created start script at: $START_SCRIPT${NC}"

# Add user to video and dialout groups for camera and serial access
if command -v sudo &> /dev/null; then
    $SUDO usermod -a -G video $USER 2>/dev/null || echo -e "${YELLOW}Could not add to video group${NC}"
    $SUDO usermod -a -G dialout $USER 2>/dev/null || echo -e "${YELLOW}Could not add to dialout group${NC}"
    echo -e "${GREEN}Added user to video and dialout groups for camera and serial access${NC}"
fi

echo -e "${GREEN}=== LaserWeb4 Installation completed ===${NC}"
echo -e "${GREEN}To use LaserWeb4:${NC}"
echo -e "${GREEN}1. Run the start script: $START_SCRIPT${NC}"
echo -e "${GREEN}2. Access the interface at: http://localhost:8000${NC}"
echo -e "${GREEN}3. To access from another device: http://[YOUR_COMPUTER_IP]:8000${NC}"
echo -e "${YELLOW}IMPORTANT:${NC}"
echo -e "${YELLOW}  - The LaserWeb4 interface runs on port 8000 by default${NC}"
echo -e "${YELLOW}  - For reliable CNC control, use the Comparatron interface${NC}"
echo -e "${YELLOW}  - Node.js v24.x compatibility may limit direct serial communication${NC}"
echo -e "${YELLOW}  - You may need to logout and login again for camera/serial group changes to take effect${NC}"
echo -e "${YELLOW}  - LaserWeb4 may take a minute or two to fully start${NC}"