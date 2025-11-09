#!/bin/bash

# Dependencies Installation Script for Comparatron
# This script will install all required Python modules for the Comparatron software

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Comparatron Dependencies Installation ===${NC}"

# Function to check if pip is available
check_pip() {
    echo -e "${YELLOW}Checking for pip...${NC}"
    
    if command -v pip3 &> /dev/null; then
        PIP_CMD=pip3
        echo -e "${GREEN}Pip3 found${NC}"
    elif command -v pip &> /dev/null; then
        PIP_CMD=pip
        echo -e "${GREEN}Pip found${NC}"
    else
        echo -e "${RED}Error: Neither pip nor pip3 is installed${NC}"
        echo "Please install pip first, then run this script again."
        exit 1
    fi
}

# Function to upgrade pip
upgrade_pip() {
    echo -e "${YELLOW}Upgrading pip...${NC}"
    
    $PIP_CMD install --upgrade pip
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Pip upgraded successfully${NC}"
    else
        echo -e "${RED}Error upgrading pip${NC}"
        exit 1
    fi
}

# Function to create dependencies folder
create_deps_folder() {
    echo -e "${YELLOW}Creating dependencies folder...${NC}"
    
    if [ ! -d "dependencies" ]; then
        mkdir dependencies
        echo -e "${GREEN}Dependencies folder created${NC}"
    else
        echo -e "${GREEN}Dependencies folder already exists${NC}"
    fi
}

# Function to install required packages
install_packages() {
    echo -e "${YELLOW}Installing required Python packages...${NC}"
    
    # List of required packages
    packages=(
        "numpy"
        "dearpygui"
        "pyserial"
        "opencv-python"
        "ezdxf"
        "serial-tools"
        "pyinstaller"
        "flask"
        "Pillow"
    )
    
    # Install each package
    for package in "${packages[@]}"; do
        echo -e "${YELLOW}Installing $package...${NC}"
        
        $PIP_CMD install "$package"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}$package installed successfully${NC}"
        else
            echo -e "${RED}Error installing $package${NC}"
            # Continue with other packages instead of exiting
        fi
    done
}

# Function to save package list for future reference
save_package_list() {
    echo -e "${YELLOW}Saving package list...${NC}"
    
    $PIP_CMD list --format=freeze > dependencies/requirements.txt
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Package list saved to dependencies/requirements.txt${NC}"
    else
        echo -e "${RED}Error saving package list${NC}"
    fi
}

# Function to download packages for offline installation (optional)
download_packages() {
    echo -e "${YELLOW}Downloading packages for offline installation (optional)...${NC}"
    
    packages=(
        "numpy"
        "dearpygui"
        "pyserial"
        "opencv-python"
        "ezdxf"
        "serial-tools"
        "pyinstaller"
    )
    
    cd dependencies
    
    for package in "${packages[@]}"; do
        echo -e "${YELLOW}Downloading $package...${NC}"
        
        $PIP_CMD download "$package" --dest . --no-deps --no-binary :all:
        
        # Also download with binary format
        $PIP_CMD download "$package" --dest .
    done
    
    cd ..
    
    echo -e "${GREEN}Packages downloaded to dependencies/ folder${NC}"
}

# Main installation process
check_pip
upgrade_pip
create_deps_folder
install_packages
save_package_list

# Ask user if they want to download packages for offline use
echo -e "${YELLOW}Do you want to download packages for offline installation?${NC}"
read -p "This will take some time and use extra storage. Continue? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    download_packages
fi

echo -e "${GREEN}=== Dependencies installation completed ===${NC}"
echo -e "${GREEN}All required packages for Comparatron have been installed.${NC}"

# Verify installation
echo -e "${YELLOW}Verifying installations...${NC}"

python3 -c "import dearpygui, cv2, numpy, serial, ezdxf, flask, PIL; print('All modules imported successfully')"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}All modules verified successfully${NC}"
else
    echo -e "${RED}Some modules failed to import${NC}"
    echo "Please run: $PIP_CMD install dearpygui opencv-python numpy pyserial ezdxf pyinstaller flask Pillow"
fi