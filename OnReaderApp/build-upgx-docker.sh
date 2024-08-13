#!/bin/bash

# Verify if cap_deploy folder exists, if not create it
if [ ! -d "cap_deploy" ]; then
    echo "cap_deploy folder does not exist. Creating folder..."
    mkdir cap_deploy
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create cap_deploy folder."
        read -p "Press enter to exit"
        exit 1
    fi
fi

# Verify if etk_tools folder exists, if not create it
if [ ! -d "etk_tools" ]; then
    echo "etk_tools folder does not exist. Creating folder..."
    mkdir etk_tools
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create etk_tools folder."
        read -p "Press enter to exit"
        exit 1
    fi
fi

# Verify if the file exists in the etk_tools folder, if not download it
if [ ! -f "etk_tools/8.1.0_Octane_Embedded_Development_Tools.tar.gz" ]; then
    echo "File not found. Downloading 8.1.0_Octane_Embedded_Development_Tools.tar.gz..."
    curl -L -o etk_tools/8.1.0_Octane_Embedded_Development_Tools.tar.gz "https://www.dropbox.com/s/oskqtyel1yg81qj/8.1.0_Octane_Embedded_Development_Tools.tar.gz?dl=1"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download the file."
        read -p "Press enter to exit"
        exit 1
    fi
fi

# Check if Docker is running
docker --version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Docker is not running or not installed."
    read -p "Press enter to exit"
    exit 1
fi

# Clearing Docker system
docker system prune -a -f
if [ $? -ne 0 ]; then
    echo "Error: Failed to prune Docker system."
    read -p "Press enter to exit"
    exit 1
fi

# Building Docker image
docker build --progress=plain --platform=linux/arm -t onreaderapp-upgx -f ./Dockerfile ../
if [ $? -ne 0 ]; then
    echo "Error: Failed to build Docker image."
    read -p "Press enter to exit"
    exit 1
fi

# Running Docker container
docker run -d --name onreaderapp-container onreaderapp-upgx 
if [ $? -ne 0 ]; then
    echo "Error: Failed to run Docker container."
    read -p "Press enter to exit"
    exit 1
fi

# Copying file from Docker container
docker container cp onreaderapp-container:/etk/onreaderapp_cap.upgx cap_deploy/
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy file from Docker container."
    read -p "Press enter to exit"
    exit 1
fi

# Removing Docker container
docker container rm -f onreaderapp-container
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove Docker container."
    read -p "Press enter to exit"
    exit 1
fi

read -p "Press enter to exit"
