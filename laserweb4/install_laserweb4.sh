#!/bin/bash

# LaserWeb4 Raspberry Pi Bookworm Installation Script
# This script installs LaserWeb4 on Raspberry Pi OS (Bookworm)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== LaserWeb4 Raspberry Pi Bookworm Installation ===${NC}"

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

# Update package list
echo -e "${YELLOW}Updating package list...${NC}"
if [ -n "$SUDO" ]; then
    $SUDO apt update -y
else
    apt update -y
fi

# Install system dependencies
echo -e "${YELLOW}Installing system dependencies...${NC}"
if [ -n "$SUDO" ]; then
    $SUDO apt install -y git curl wget build-essential python3 python3-pip nodejs npm nginx
else
    apt install -y git curl wget build-essential python3 python3-pip nodejs npm nginx
fi

# Check if Node.js and npm are properly installed
echo -e "${YELLOW}Checking Node.js and npm versions...${NC}"
if command -v node &> /dev/null; then
    node --version
else
    # Try nodejs command (different name on some systems)
    if command -v nodejs &> /dev/null; then
        nodejs --version
    else
        echo -e "${RED}Node.js is not installed properly${NC}"
        exit 1
    fi
fi

if command -v npm &> /dev/null; then
    npm --version
else
    echo -e "${RED}npm is not installed properly${NC}"
    exit 1
fi

# Create user directory if needed and navigate to it
INSTALL_DIR="$HOME/LaserWeb"
echo -e "${YELLOW}Installing LaserWeb4 to: $INSTALL_DIR${NC}"

# Clone LaserWeb repository
echo -e "${YELLOW}Cloning LaserWeb4 repository...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}LaserWeb directory already exists, updating...${NC}"
    cd "$INSTALL_DIR"
    git pull
else
    git clone https://github.com/LaserWeb/LaserWeb4.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Install Node.js dependencies
echo -e "${YELLOW}Installing Node.js dependencies (this may take a while on Raspberry Pi)...${NC}"
npm install --production --prefer-offline --no-audit --no-fund

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
    cat > "$INSTALL_DIR/config.json" << EOF
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
START_SCRIPT="$HOME/start_laserweb.sh"
cat > "$START_SCRIPT" << EOF
#!/bin/bash
cd $INSTALL_DIR
npm start
EOF

chmod +x "$START_SCRIPT"
echo -e "${GREEN}Created start script at: $START_SCRIPT${NC}"

# Create a systemd service file for LaserWeb
SERVICE_FILE="/etc/systemd/system/laserweb.service"
SERVICE_CONTENT="[Unit]
Description=LaserWeb4 CNC Control
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

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