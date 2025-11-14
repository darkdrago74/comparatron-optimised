#!/bin/bash

# Virtual Environment Zip and Split Script for GitHub
# Creates a compressed zip of the virtual environment and splits it for GitHub upload

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Virtual Environment Zip and Split for GitHub ===${NC}"

# Check if virtual environment exists (in the parent directory)
VENV_PATH="../comparatron_env"
if [ ! -d "$VENV_PATH" ]; then
    echo -e "${RED}Error: Virtual environment not found at $VENV_PATH${NC}"
    echo -e "${YELLOW}Run the installation script first to create the virtual environment${NC}"
    exit 1
fi

# Remove any existing zip files and split files before creating new ones
echo -e "${YELLOW}Cleaning up previous zip and split files...${NC}"
if [ -f "./comparatron_env.tar.gz" ]; then
    rm -f "./comparatron_env.tar.gz"
    echo -e "${YELLOW}Removed existing comparatron_env.tar.gz${NC}"
fi

# Create venv_splits directory and clean up any existing split files
SPLITS_DIR="venv_splits"
mkdir -p "$SPLITS_DIR"

# Remove existing split files and main archive
rm -f "$SPLITS_DIR/comparatron_env_main.tar.gz"
rm -f "$SPLITS_DIR/comparatron_env_part_"*
rm -f "$SPLITS_DIR/split_info.txt"

echo -e "${YELLOW}Previous split files and archives have been removed${NC}"

echo -e "${YELLOW}Virtual environment size: $(du -sh "$VENV_PATH" | cut -f1)${NC}"
echo -e "${YELLOW}Compressing and splitting virtual environment...${NC}"

# Create a compressed tar of the virtual environment (from parent directory)
MAIN_TAR="$SPLITS_DIR/comparatron_env_main.tar.gz"
echo -e "${YELLOW}Creating compressed archive...${NC}"
tar -czf "$MAIN_TAR" -C ".." "comparatron_env"

# Get the size of the compressed archive
MAIN_SIZE=$(du -sh "$MAIN_TAR" | cut -f1)
echo -e "${GREEN}Compressed virtual environment size: $MAIN_SIZE${NC}"

# Split into 20MB chunks (to meet GitHub 25MB limit)
CHUNK_SIZE=20M
echo -e "${YELLOW}Splitting into ${CHUNK_SIZE} chunks...${NC}"

# Split the compressed archive
cd "$SPLITS_DIR"
split -b $CHUNK_SIZE "comparatron_env_main.tar.gz" "comparatron_env_part_"
cd ..

# Count how many parts were created
PART_COUNT=$(ls $SPLITS_DIR/comparatron_env_part_* 2>/dev/null | wc -l)
echo -e "${GREEN}Successfully created ${PART_COUNT} split files in $SPLITS_DIR/${NC}"

# List the split files
echo -e "${YELLOW}Split files created:${NC}"
ls -lh "$SPLITS_DIR/"

# Create information file
cat > "$SPLITS_DIR/split_info.txt" << EOF
Virtual Environment Split Information:
--------------------------------------
Original size: $(du -sh "$VENV_PATH" | cut -f1)
Compressed size: $(du -sh "$SPLITS_DIR/comparatron_env_main.tar.gz" | cut -f1)
Split into parts of: $CHUNK_SIZE each
Number of parts: $PART_COUNT
Files: $(ls $SPLITS_DIR/comparatron_env_part_* 2>/dev/null | head -10)
To recombine: cd venv_splits && cat comparatron_env_part_* > ../comparatron_env_main.tar.gz && cd .. && tar -xzf comparatron_env_main.tar.gz
EOF

echo -e "${GREEN}=== Virtual environment zipped and split successfully ===${NC}"
echo -e "${GREEN}Upload all files in the $SPLITS_DIR/ folder to GitHub${NC}"
echo -e "${GREEN}Each part is under 25MB and meets GitHub size limits${NC}"