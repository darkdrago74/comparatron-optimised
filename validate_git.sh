#!/bin/bash

# Git Validation Script for Comparatron Optimization
# This script will help track and validate changes during the optimization process

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Git Validation for Comparatron Optimization ===${NC}"

# Function to validate git status
validate_git_status() {
    echo -e "${YELLOW}Checking git status...${NC}"
    
    if ! git status &> /dev/null; then
        echo -e "${RED}Error: Not in a git repository or git not available${NC}"
        exit 1
    fi
    
    # Check for uncommitted changes
    if [[ $(git status --porcelain) ]]; then
        echo -e "${RED}Warning: Uncommitted changes detected${NC}"
        echo "Current changes:"
        git status --porcelain
        read -p "Do you want to commit these changes before proceeding? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter commit message: " commit_msg
            git add .
            git commit -m "$commit_msg"
        else
            echo -e "${YELLOW}Proceeding without committing changes...${NC}"
        fi
    fi
    
    echo -e "${GREEN}Git status is clean${NC}"
}

# Function to create a backup branch before major changes
create_backup_branch() {
    local branch_name="backup-$(date +%Y%m%d-%H%M%S)"
    echo -e "${YELLOW}Creating backup branch: $branch_name${NC}"
    git checkout -b "$branch_name"
    git checkout main
    echo -e "${GREEN}Backup branch created: $branch_name${NC}"
}

# Function to validate that we're on the correct branch
validate_branch() {
    local current_branch=$(git branch --show-current)
    echo -e "${YELLOW}Current branch: $current_branch${NC}"
    
    if [[ "$current_branch" != "main" ]]; then
        echo -e "${YELLOW}Switching to main branch${NC}"
        git checkout main
    fi
}

# Main validation process
validate_branch
validate_git_status
create_backup_branch

echo -e "${GREEN}=== Git validation completed successfully ===${NC}"