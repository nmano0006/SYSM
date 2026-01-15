#!/bin/bash

# Base path
BASE_PATH="/Users/z790/Desktop/SystemMaintenanceMac/SystemMaintenance/SystemMaintenance"

# Create main directory and common subdirectories
echo "Creating directory structure..."
mkdir -p "$BASE_PATH"/{Scripts,Logs,Backups,Config,Tools,Reports}

# Create sample files
touch "$BASE_PATH/README.md"
touch "$BASE_PATH/Scripts/backup_script.sh"
touch "$BASE_PATH/Logs/maintenance.log"
touch "$BASE_PATH/Config/settings.conf"

# Set permissions for scripts
chmod +x "$BASE_PATH/Scripts/backup_script.sh"

# Verify creation
echo "Directory structure created:"
find "/Users/z790/Desktop/SystemMaintenanceMac" -type d | sort

# List contents
echo -e "\nContents of SystemMaintenance directory:"
ls -la "$BASE_PATH"