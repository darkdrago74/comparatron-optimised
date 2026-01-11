#!/bin/bash
# LaserWeb4 Raspberry Pi Bookworm Installation Script
# This script installs LaserWeb4 on Raspberry Pi OS (Bookworm)
# Fixed version to address serialport compilation issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== LaserWeb4 Raspberry Pi Bookworm Installation (Fixed) ===${NC}"

# Function to display menu and get user choice
show_menu() {
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "1) Install LaserWeb4"
    echo "2) Uninstall LaserWeb4"
    echo "3) Check current installation status"
    read -p "Enter your choice (1-3, default is 1): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[2]$ ]]; then
        ACTION="uninstall"
    elif [[ $REPLY =~ ^[3]$ ]]; then
        ACTION="check"
    else
        ACTION="install"
    fi
}

show_menu

if [ "$ACTION" = "check" ]; then
    echo -e "${YELLOW}=== Checking LaserWeb4 Installation Status ===${NC}"
    
    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "${GREEN}✓ Node.js version: $NODE_VERSION${NC}"
    elif command -v nodejs &> /dev/null; then
        NODE_VERSION=$(nodejs --version)
        echo -e "${GREEN}✓ Node.js version: $NODE_VERSION${NC}"
    else
        echo -e "${RED}✗ Node.js not installed${NC}"
    fi
    
    # Check npm
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        echo -e "${GREEN}✓ npm version: $NPM_VERSION${NC}"
    else
        echo -e "${RED}✗ npm not installed${NC}"
    fi
    
    # Check LaserWeb directories
    if [ -d "$HOME/LaserWeb" ]; then
        echo -e "${GREEN}✓ LaserWeb directory found at: $HOME/LaserWeb${NC}"
    else
        echo -e "${RED}✗ LaserWeb directory not found${NC}"
    fi

    if [ -d "$HOME/LaserWeb4" ]; then
        echo -e "${GREEN}✓ LaserWeb4 directory found at: $HOME/LaserWeb4${NC}"
    else
        echo -e "${RED}✗ LaserWeb4 directory not found${NC}"
    fi

    if [ -d "$HOME/lw.comm-server" ]; then
        echo -e "${GREEN}✓ lw.comm-server directory found at: $HOME/lw.comm-server${NC}"
    else
        echo -e "${RED}✗ lw.comm-server directory not found${NC}"
    fi
    
    # Check service
    if systemctl is-active --quiet laserweb.service; then
        echo -e "${GREEN}✓ LaserWeb service is running${NC}"
    elif [ -f "/etc/systemd/system/laserweb.service" ]; then
        echo -e "${YELLOW}~ LaserWeb service exists but is not running${NC}"
    else
        echo -e "${RED}✗ LaserWeb service not found${NC}"
    fi
    
    # Check required libraries
    if command -v dpkg &> /dev/null; then
        if dpkg -l | grep -q libusb-1.0-0-dev; then
            echo -e "${GREEN}✓ libusb-1.0-0-dev is installed${NC}"
        else
            echo -e "${RED}✗ libusb-1.0-0-dev is not installed${NC}"
        fi
        
        if dpkg -l | grep -q libudev-dev; then
            echo -e "${GREEN}✓ libudev-dev is installed${NC}"
        else
            echo -e "${RED}✗ libudev-dev is not installed${NC}"
        fi
    fi
    
    exit 0
fi

if [ "$ACTION" = "uninstall" ]; then
    echo -e "${YELLOW}=== LaserWeb4 Complete Uninstallation ===${NC}"

    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
            echo -e "${GREEN}Sudo available${NC}"
        else
            echo -e "${RED}Error: sudo is required but not available.${NC}"
            exit 1
        fi
    else
        SUDO=""
        echo -e "${GREEN}Running as root${NC}"
    fi

    # Stop and disable LaserWeb service if it exists
    if [ -f "/etc/systemd/system/laserweb.service" ]; then
        echo -e "${YELLOW}Stopping LaserWeb service...${NC}"
        $SUDO systemctl stop laserweb.service 2>/dev/null || true
        $SUDO systemctl disable laserweb.service 2>/dev/null || true
        echo -e "${GREEN}✓ LaserWeb service stopped and disabled${NC}"
        
        # Remove service file
        $SUDO rm -f /etc/systemd/system/laserweb.service
        $SUDO systemctl daemon-reload
        echo -e "${GREEN}✓ LaserWeb service file removed${NC}"
    else
        echo -e "${YELLOW}LaserWeb service not found${NC}"
    fi

    # Remove nginx configuration if it exists
    if [ -f "/etc/nginx/sites-available/laserweb" ]; then
        echo -e "${YELLOW}Removing nginx configuration...${NC}"
        $SUDO rm -f /etc/nginx/sites-available/laserweb
        $SUDO rm -f /etc/nginx/sites-enabled/laserweb
        $SUDO systemctl reload nginx 2>/dev/null || true
        echo -e "${GREEN}✓ Nginx configuration removed${NC}"
    else
        echo -e "${YELLOW}Nginx configuration for LaserWeb not found${NC}"
    fi

    # Remove LaserWeb directories
    LASERWEB_DIRS=("$HOME/LaserWeb" "$HOME/LaserWeb4" "$HOME/lw.comm-server")
    for dir in "${LASERWEB_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}Removing LaserWeb directory: $dir${NC}"
            rm -rf "$dir"
            echo -e "${GREEN}✓ $dir removed${NC}"
        else
            echo -e "${YELLOW}LaserWeb directory $dir not found${NC}"
        fi
    done

    # Remove start scripts
    START_SCRIPTS=("$HOME/start_laserweb.sh" "$HOME/start_laserweb4.sh" "$HOME/start_laserweb_combined.sh")
    for script in "${START_SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            echo -e "${YELLOW}Removing start script: $script${NC}"
            rm -f "$script"
            echo -e "${GREEN}✓ $script removed${NC}"
        else
            echo -e "${YELLOW}Start script $script not found${NC}"
        fi
    done

    # Remove global npm packages related to LaserWeb
    echo -e "${YELLOW}Checking for global npm packages...${NC}"
    if command -v npm &> /dev/null; then
        if npm list -g lw.comm-server &> /dev/null; then
            echo -e "${YELLOW}Removing lw.comm-server global package...${NC}"
            $SUDO npm uninstall -g lw.comm-server 2>/dev/null || true
            echo -e "${GREEN}✓ lw.comm-server removed${NC}"
        else
            echo -e "${YELLOW}lw.comm-server not found${NC}"
        fi
    else
        echo -e "${YELLOW}npm not available, skipping global package removal${NC}"
    fi

    # Check and potentially remove Node.js if it was installed by this script
    echo -e "${YELLOW}Checking Node.js installation...${NC}"
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "${GREEN}Node.js version: $NODE_VERSION${NC}"
        
        # Ask user if they want to remove Node.js as well
        echo -e "${YELLOW}Would you like to remove Node.js as well?${NC}"
        echo -e "${YELLOW}This will only remove Node.js if you're sure you don't need it for other projects. (y/N): ${NC}"
        read -p "" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Removing Node.js...${NC}"
            $SUDO apt remove -y nodejs npm 2>/dev/null || true
            $SUDO apt autoremove -y 2>/dev/null || true
            # Remove NodeSource repository if it exists
            $SUDO rm -f /etc/apt/sources.list.d/nodesource.list
            $SUDO rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true
            echo -e "${GREEN}✓ Node.js removed${NC}"
        fi
    fi

    # Remove user from dialout group (optional - ask user)
    echo -e "${YELLOW}Would you like to remove the current user from the dialout group?${NC}"
    echo -e "${YELLOW}This will affect access to serial ports. (y/N): ${NC}"
    read -p "" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v sudo &> /dev/null; then
            $SUDO deluser $USER dialout 2>/dev/null || true
            echo -e "${GREEN}✓ User removed from dialout group${NC}"
        fi
    fi

    # Clean npm cache (optional - ask user)
    echo -e "${YELLOW}Would you like to clean npm cache? (y/N): ${NC}"
    read -p "" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        npm cache clean --force 2>/dev/null || true
        rm -rf ~/.npm 2>/dev/null || true
        echo -e "${GREEN}✓ npm cache cleaned${NC}"
    fi

    echo -e "${GREEN}=== LaserWeb4 Complete Uninstallation Finished ===${NC}"
    echo -e "${GREEN}LaserWeb4 has been completely removed from your system.${NC}"
    echo -e "${GREEN}You may need to log out and log back in for group changes to take effect.${NC}"
    
    exit 0
fi

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &> /dev/null; then
        SUDO="sudo"
        echo -e "${GREEN}Sudo available${NC}"
    else
        echo -e "${RED}Error: sudo is required but not available.${NC}"
        exit 1
    fi
else
    SUDO=""
    echo -e "${GREEN}Running as root${NC}"
fi

# Check current Node.js version and offer to reinstall
CURRENT_NODE_VERSION=""
if command -v node &> /dev/null; then
    CURRENT_NODE_VERSION=$(node --version)
    echo -e "${YELLOW}Current Node.js version: $CURRENT_NODE_VERSION${NC}"
elif command -v nodejs &> /dev/null; then
    CURRENT_NODE_VERSION=$(nodejs --version)
    echo -e "${YELLOW}Current Node.js version: $CURRENT_NODE_VERSION${NC}"
else
    echo -e "${YELLOW}Node.js is not currently installed${NC}"
    CURRENT_NODE_VERSION="none"
fi

# Ask user which version to install
echo -e "${YELLOW}Which Node.js version would you like to install?${NC}"
echo -e "${YELLOW}1) Node.js 18 (recommended, proven to work well with LaserWeb4)${NC}"
echo -e "${YELLOW}2) Node.js 16 (alternative option)${NC}"
echo -e "${YELLOW}3) Node.js 12 (older stable version, may improve compatibility)${NC}"
read -p "Enter your choice (1-3, default is 1): " -n 1 -r
echo
if [[ $REPLY =~ ^[2]$ ]]; then
    NODE_VERSION_CHOICE="16"
    echo -e "${GREEN}Selected Node.js 16${NC}"
elif [[ $REPLY =~ ^[3]$ ]]; then
    NODE_VERSION_CHOICE="12"
    echo -e "${GREEN}Selected Node.js 12${NC}"
    echo -e "${YELLOW}Note: Node.js 12 is end-of-life but may provide better compatibility with older LaserWeb4 versions${NC}"
else
    NODE_VERSION_CHOICE="18"
    echo -e "${GREEN}Selected Node.js 18${NC}"
fi

# If Node.js is already installed, ask if user wants to reinstall
if [ "$CURRENT_NODE_VERSION" != "none" ]; then
    echo -e "${YELLOW}Node.js is currently installed: $CURRENT_NODE_VERSION${NC}"
    read -p "Uninstall current Node.js and install Node.js $NODE_VERSION_CHOICE? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${GREEN}Using existing Node.js installation${NC}"
        # Check if required libraries for serialport functionality are installed
        if ! $SUDO dpkg -l | grep -q libusb-1.0-0-dev && ! $SUDO dpkg -l | grep -q libudev-dev; then
            echo -e "${YELLOW}Installing required libraries for serialport functionality...${NC}"
            $SUDO apt install -y libusb-1.0-0-dev libudev-dev
        fi
    else
        echo -e "${YELLOW}Removing current Node.js installation...${NC}"
        $SUDO apt remove -y nodejs npm 2>/dev/null || true
        $SUDO apt autoremove -y 2>/dev/null || true
        # Remove NodeSource repository if it exists
        $SUDO rm -f /etc/apt/sources.list.d/nodesource.list
        $SUDO rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true
        # Clean npm cache
        npm cache clean --force 2>/dev/null || true
        rm -rf ~/.npm 2>/dev/null || true
        
        # Install the selected Node.js version
        echo -e "${YELLOW}Installing Node.js $NODE_VERSION_CHOICE using Nodesource setup script...${NC}"
        if command -v curl &> /dev/null; then
            if command -v sudo &> /dev/null; then
                # For Node.js 12, we need to handle it differently as it's EOL
                if [ "$NODE_VERSION_CHOICE" = "12" ]; then
                    # Check if we're on a compatible system for Node.js 12
                    echo -e "${YELLOW}Installing Node.js $NODE_VERSION_CHOICE (end-of-life)${NC}"
                    curl -fsSL https://deb.nodesource.com/setup_12.x | sudo -E bash -
                    sudo apt-get install -y nodejs
                else
                    curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION_CHOICE.x | sudo -E bash -
                    sudo apt-get install -y nodejs
                fi
                echo -e "${GREEN}✓ Node.js $NODE_VERSION_CHOICE.x installed${NC}"
            else
                echo -e "${RED}Error: sudo not available. Cannot install Node.js automatically.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Error: curl not available. Cannot download NodeSource setup script.${NC}"
            exit 1
        fi
        
        # Install required libraries for serialport functionality (needed for both Node.js 16 and 18)
        echo -e "${YELLOW}Installing required libraries for serialport functionality...${NC}"
        $SUDO apt install -y libusb-1.0-0-dev libudev-dev
    fi
else
    # Install the selected Node.js version
    echo -e "${YELLOW}Installing Node.js $NODE_VERSION_CHOICE using Nodesource setup script...${NC}"
    if command -v curl &> /dev/null; then
        if command -v sudo &> /dev/null; then
            # Update package list first
            $SUDO apt update -y
            
            # Install system dependencies
            $SUDO apt install -y git curl wget build-essential python3 python3-pip nginx
            
            # Install Node.js
            curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION_CHOICE.x | sudo -E bash -
            sudo apt-get install -y nodejs
            echo -e "${GREEN}✓ Node.js $NODE_VERSION_CHOICE.x installed${NC}"
            
            # Install required libraries for serialport functionality (needed for both Node.js 16 and 18)
            echo -e "${YELLOW}Installing required libraries for serialport functionality...${NC}"
            $SUDO apt install -y libusb-1.0-0-dev libudev-dev
        else
            echo -e "${RED}Error: sudo not available. Cannot install Node.js automatically.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error: curl not available. Cannot download NodeSource setup script.${NC}"
        exit 1
    fi
fi

# Verify Node.js installation
NODE_VERSION=$(node --version 2>/dev/null || nodejs --version 2>/dev/null)
if [ -z "$NODE_VERSION" ]; then
    echo -e "${RED}Error: Node.js installation failed.${NC}"
    exit 1
fi

NPM_VERSION=$(npm --version 2>/dev/null)
if [ -z "$NPM_VERSION" ]; then
    echo -e "${RED}Error: npm installation failed.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Node.js $NODE_VERSION and npm $NPM_VERSION are installed${NC}"

# Create user directory if needed and navigate to it
INSTALL_DIR="$HOME/LaserWeb4"
echo -e "${YELLOW}Installing LaserWeb4 to: $INSTALL_DIR${NC}"

# Clone LaserWeb4 repository (using the correct repository)
echo -e "${YELLOW}Cloning LaserWeb4 repository...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}LaserWeb4 directory already exists, updating...${NC}"
    cd "$INSTALL_DIR"
    git pull
else
    git clone https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Also install lw.comm-server as mentioned in LaserWeb documentation
echo -e "${YELLOW}Installing lw.comm-server as recommended in LaserWeb documentation...${NC}"
LWCOMM_DIR="$HOME/lw.comm-server"
if [ -d "$LWCOMM_DIR" ]; then
    echo -e "${YELLOW}lw.comm-server directory already exists, updating...${NC}"
    cd "$LWCOMM_DIR"
    git pull
else
    git clone https://github.com/LaserWeb/lw.comm-server.git "$LWCOMM_DIR"
    cd "$LWCOMM_DIR"
    # Install lw.comm-server dependencies
    npm install
fi

# Install Node.js dependencies with production flags to avoid dev dependencies that might cause issues
echo -e "${YELLOW}Installing Node.js dependencies (this may take a while on Raspberry Pi)...${NC}"
npm install --production --prefer-offline --no-audit --no-fund

# If the above fails due to serialport issues, try installing with legacy peer deps and build from source
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Standard install failed, trying with legacy peer deps and serialport rebuild...${NC}"
    
    # Clear npm cache
    npm cache clean --force
    
    # Try installing with legacy peer deps flag
    npm install --production --prefer-offline --no-audit --no-fund --legacy-peer-deps
    
    # If still failing, try to rebuild serialport specifically
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Trying to install serialport separately with specific version...${NC}"
        
        # Install a known working version of serialport
        npm install serialport@10.5.0 --no-audit --no-fund
        
        # Then install remaining dependencies
        npm install --production --prefer-offline --no-audit --no-fund --legacy-peer-deps
    fi
fi

# If still failing, try using prebuilt binaries for serialport
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Trying to install with prebuilt serialport binaries...${NC}"
    
    # Force installation of prebuilt serialport binaries
    npm install --production --prefer-offline --no-audit --no-fund --legacy-peer-deps --build-from-source=false
fi

# If all else fails, try installing with unsafe-perm (for ARM/Raspberry Pi issues)
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Trying to install with unsafe permissions (for ARM/Raspberry Pi)...${NC}"
    npm install --production --unsafe-perm --prefer-offline --no-audit --no-fund --legacy-peer-deps
fi

# Check if installation was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to install LaserWeb4 dependencies.${NC}"
    echo -e "${RED}This may be due to serialport compilation issues on ARM architecture.${NC}"
    echo -e "${YELLOW}Trying alternative approach with specific serialport configuration...${NC}"
    
    # Set npm configuration for ARM architecture
    npm config set python python3
    npm config set nodedir /usr/include/nodejs
    
    # Try installing serialport with specific flags for ARM
    npm install serialport --build-from-source --verbose
    
    # Then install other dependencies
    npm install --production --prefer-offline --no-audit --no-fund --legacy-peer-deps
fi

# Check final installation status
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to install LaserWeb4 dependencies after multiple attempts.${NC}"
    if [ "$NODE_VERSION_CHOICE" = "18" ]; then
        echo -e "${YELLOW}Node.js 18 may have compatibility issues with LaserWeb4 dependencies.${NC}"
        echo -e "${YELLOW}Consider reinstalling with Node.js 16 for better compatibility.${NC}"
    else
        echo -e "${YELLOW}You may need to check system dependencies or try Node.js 18 with additional libraries.${NC}"
    fi
    exit 1
fi

echo -e "${GREEN}✓ LaserWeb4 dependencies installed successfully${NC}"

# Install specific versions of development dependencies that are compatible with LaserWeb4
echo -e "${YELLOW}Installing compatible versions of development dependencies for LaserWeb4...${NC}"

# Install specific compatible versions to avoid CLI option conflicts
npm install --save-dev npm-run-all webpack-dev-server@^3.11.3 webpack-cli@^4.10.0 || {
    echo -e "${YELLOW}Trying alternative installation with latest compatible versions...${NC}"
    npm install --save-dev npm-run-all webpack-dev-server webpack-cli
}

# Modify package.json to remove deprecated --colors option
if [ -f "package.json" ]; then
    echo -e "${YELLOW}Updating package.json to remove deprecated webpack options...${NC}"
    # Create a temporary file with the updated content
    TEMP_FILE=$(mktemp)
    # Use sed to remove the --colors option from the start-app script
    sed 's/--colors//g' package.json > "$TEMP_FILE" && mv "$TEMP_FILE" package.json
    # Also remove --progress if it's causing issues
    TEMP_FILE=$(mktemp)
    sed 's/--progress//g' package.json > "$TEMP_FILE" && mv "$TEMP_FILE" package.json
    # Clean up any extra spaces
    TEMP_FILE=$(mktemp)
    sed 's/  */ /g' package.json > "$TEMP_FILE" && mv "$TEMP_FILE" package.json
fi

# Build LaserWeb for production (only if build script exists)
echo -e "${YELLOW}Checking for build scripts in LaserWeb4...${NC}"
if [ -f "$INSTALL_DIR/package.json" ]; then
    # Read the package.json to see if a build script is defined
    if grep -q '"build"' "$INSTALL_DIR/package.json"; then
        echo -e "${YELLOW}Building LaserWeb4 (this may take several minutes on Raspberry Pi, skipping if not needed)...${NC}"
        # Try to build but allow it to fail if build script is not available
        npm run build || echo -e "${YELLOW}Build step skipped (not required or failed)${NC}"
    else
        echo -e "${YELLOW}No build script found in package.json, continuing...${NC}"
    fi
else
    echo -e "${YELLOW}No package.json found in LaserWeb4, continuing...${NC}"
fi

# Set up configuration
echo -e "${YELLOW}Setting up LaserWeb4 configuration...${NC}"

# Create default config if it doesn't exist
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    cat > "$INSTALL_DIR/config.json" << 'EOF'
{
  "server": {
    "port": 8000,
    "host": "0.0.0.0",
    "ssl": false,
    "sslPort": 8443,
    "sslCert": "",
    "sslKey": "",
    "sslPass": "",
    "socketIoPath": "/socket.io"
  },
  "app": {
    "title": "LaserWeb4 - CNC Control"
  },
  "defaults": {
    "language": "en",
    "theme": "dark",
    "gcode": {
      "arcApproximation": 0.5,
      "laserPowerRange": [0, 1000]
    }
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
fi

# Create a minimal start script for development/testing
START_SCRIPT="$HOME/start_laserweb4.sh"
cat > "$START_SCRIPT" << 'EOF'
#!/bin/bash
cd $INSTALL_DIR
npm start
EOF
chmod +x "$START_SCRIPT"
echo -e "${GREEN}Created start script at: $START_SCRIPT${NC}"

# Create a combined start script that starts both lw.comm-server and LaserWeb4
COMBINED_START_SCRIPT="$HOME/start_laserweb_combined.sh"
cat > "$COMBINED_START_SCRIPT" << 'EOF'
#!/bin/bash
# Start lw.comm-server first
echo "Starting lw.comm-server..."
cd $HOME/lw.comm-server
node server &
LWCOMM_PID=$!

# Wait a moment for lw.comm-server to start
sleep 5

# Verify lw.comm-server is running
if ps -p $LWCOMM_PID > /dev/null; then
    echo "lw.comm-server started successfully (PID: $LWCOMM_PID)"
else
    echo "ERROR: lw.comm-server failed to start"
    exit 1
fi

# Wait a bit more for lw.comm-server to fully initialize
sleep 3

# Start LaserWeb4 (only the app part, not the server part that conflicts with lw.comm-server)
echo "Starting LaserWeb4..."
cd $HOME/LaserWeb4

# Check if we should run in development mode or production mode
if [ -f "package.json" ]; then
    # Check if the start script in package.json is trying to run both app and server
    # If it's trying to run both, we'll run just the app part since lw.comm-server is already running
    if grep -q "start-server" package.json; then
        # Run only the app part to avoid conflicts
        echo "Running LaserWeb4 in app-only mode (to avoid conflicts with lw.comm-server)"
        npm run start-app
    else
        # Just run the standard start
        npm start
    fi
else
    # Fallback: try to run directly
    if [ -f "dist/server.js" ]; then
        node dist/server.js
    elif [ -f "server.js" ]; then
        node server.js
    else
        echo "LaserWeb4: Attempting to start with fallback method..."
        npm start
    fi
fi

# Clean up background processes when script exits
trap "kill $LWCOMM_PID 2>/dev/null; exit" INT TERM EXIT
EOF
chmod +x "$COMBINED_START_SCRIPT"
echo -e "${GREEN}Created combined start script at: $COMBINED_START_SCRIPT${NC}"

# Create a systemd service file for LaserWeb
SERVICE_FILE="/etc/systemd/system/laserweb.service"
SERVICE_CONTENT="[Unit]
Description=LaserWeb4 CNC Control with lw.comm-server
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$COMBINED_START_SCRIPT
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

if [ -n "$SUDO" ]; then
    echo "$SERVICE_CONTENT" | $SUDO tee "$SERVICE_FILE"
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable laserweb.service
    echo -e "${GREEN}LaserWeb service enabled to start on boot${NC}"
else
    echo "$SERVICE_CONTENT" | tee "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable laserweb.service
    echo -e "${GREEN}LaserWeb service enabled to start on boot${NC}"
fi

# Configure nginx as reverse proxy (optional)
echo -e "${YELLOW}Configuring nginx as reverse proxy (optional)...${NC}"
NGINX_CONFIG="/etc/nginx/sites-available/laserweb"
NGINX_SITE="/etc/nginx/sites-enabled/laserweb"
NGINX_CONTENT="server {
    listen 8080;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}"

if [ -n "$SUDO" ]; then
    echo "$NGINX_CONTENT" | $SUDO tee "$NGINX_CONFIG"
    if [ ! -L "$NGINX_SITE" ]; then
        $SUDO ln -s "$NGINX_CONFIG" "$NGINX_SITE"
    fi
    $SUDO systemctl restart nginx
    $SUDO systemctl enable nginx
fi

# Add user to dialout group for serial access
if [ -n "$SUDO" ]; then
    $SUDO usermod -a -G dialout $USER
    echo -e "${GREEN}User added to dialout group for serial port access${NC}"
fi

echo -e "${GREEN}=== LaserWeb4 Installation completed ===${NC}"
echo -e "${GREEN}To use LaserWeb4:${NC}"
echo -e "${GREEN}1. The service will automatically start on boot${NC}"
echo -e "${GREEN}2. Access the interface at: http://[RPI_IP_ADDRESS]:8000${NC}"
if [ -n "$SUDO" ]; then
    echo -e "${GREEN}3. Alternative access via nginx: http://[RPI_IP_ADDRESS]:8080${NC}"
fi
echo -e "${GREEN}4. To restart the service manually: sudo systemctl restart laserweb${NC}"
echo -e "${GREEN}5. To check service status: sudo systemctl status laserweb${NC}"
echo -e "${GREEN}${NC}"
echo -e "${GREEN}Note: After adding to dialout group, log out and log back in for camera/serial access.${NC}"

echo -e "${GREEN}Node.js version used: $NODE_VERSION_CHOICE${NC}"
if [ "$NODE_VERSION_CHOICE" = "12" ]; then
    echo -e "${YELLOW}Note: Node.js 12 is end-of-life but may provide better compatibility with older LaserWeb4 versions${NC}"
fi
echo -e "${GREEN}Additional libraries installed: libusb-1.0-0-dev libudev-dev${NC}"