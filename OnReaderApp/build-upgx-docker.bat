@echo off
setlocal

REM Verify if cap_deploy folder exists, if not create it
if not exist "cap_deploy" (
    echo cap_deploy folder does not exist. Creating folder...
    mkdir cap_deploy
    if %errorlevel% neq 0 (
        echo Error: Failed to create cap_deploy folder.
        pause
        exit /b 1
    )
)

REM Verify if etk_tools folder exists, if not create it
if not exist "etk_tools" (
    echo etk_tools folder does not exist. Creating folder...
    mkdir etk_tools
    if %errorlevel% neq 0 (
        echo Error: Failed to create etk_tools folder.
        pause
        exit /b 1
    )
)

REM Verify if the file exists in the etk_tools folder, if not download it
if not exist "etk_tools\8.1.0_Octane_Embedded_Development_Tools.tar.gz" (
    echo File not found. Downloading 8.1.0_Octane_Embedded_Development_Tools.tar.gz...
    powershell -Command "Invoke-WebRequest -Uri https://www.dropbox.com/s/oskqtyel1yg81qj/8.1.0_Octane_Embedded_Development_Tools.tar.gz?dl=1 -OutFile etk_tools\8.1.0_Octane_Embedded_Development_Tools.tar.gz"
    if %errorlevel% neq 0 (
        echo Error: Failed to download the file.
        pause
        exit /b 1
    )
)

REM Check if Docker is running
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Docker is not running or not installed.
    pause
    exit /b 1
)

REM Clearing Docker system
docker system prune -a -f
if %errorlevel% neq 0 (
    echo Error: Failed to prune Docker system.
    pause
    exit /b 1
)

REM Building Docker image
docker build --progress=plain --platform=linux/arm -t onreaderapp-upgx -f ./Dockerfile ../
if %errorlevel% neq 0 (
    echo Error: Failed to build Docker image.
    pause
    exit /b 1
)

REM Running Docker container
docker run -d --name onreaderapp-container onreaderapp-upgx 
if %errorlevel% neq 0 (
    echo Error: Failed to run Docker container.
    pause
    exit /b 1
)

REM Copying file from Docker container
docker container cp onreaderapp-container:/etk/onreaderapp_cap.upgx cap_deploy/
if %errorlevel% neq 0 (
    echo Error: Failed to copy file from Docker container.
    pause
    exit /b 1
)

REM Removing Docker container
docker container rm -f onreaderapp-container
if %errorlevel% neq 0 (
    echo Error: Failed to remove Docker container.
    pause
    exit /b 1
)

pause
