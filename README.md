# On-Reader Application Boilerplate for R700 Readers

This repository provides a boilerplate project for building, publishing, and packing an on-reader application for R700 readers. It leverages Docker for cross-platform development, targeting ARM architecture.

## Project Structure

- **Dockerfile**: The Dockerfile used to build, publish, and package the on-reader application.
- **Scripts**: Batch and shell scripts for managing the build, publish, and packaging process.
- **OnReaderApp**: The .NET project directory containing the on-reader application code.

## Prerequisites

- **Docker**: Ensure Docker is installed and running on your system.
- **.NET SDK 8.0**: Required for building and publishing the .NET application.

## Building the Project

To build the project using Docker, follow the steps below:

### 1. Verify Directories

Ensure that the following directories exist in your project structure:

- `cap_deploy`: Used to store the final packaged application.
- `etk_tools`: Used to store required development tools.

If these directories do not exist, they will be automatically created by the provided scripts.

### 2. Scripts Overview

There are two scripts provided for managing the project:

- **Batch Script** (`build.bat`): For Windows users.
- **Shell Script** (`build.sh`): For Linux/Mac users.

### 3. Running the Script

#### Windows:

1. Run the `build.bat` script.
2. The script will:
   - Check if Docker is installed and running.
   - Create the `cap_deploy` and `etk_tools` directories if they do not exist.
   - Verify if the required tool (`8.1.0_Octane_Embedded_Development_Tools.tar.gz`) is present in the `etk_tools` directory. If not, it will be downloaded automatically.
   - Build and package the on-reader application.

#### Linux/Mac:

1. Run the `build.sh` script.
2. The script will perform the same steps as the batch script for Windows.

## Dockerfile Overview

The `Dockerfile` provided in this repository supports cross-platform builds targeting ARM architecture. It consists of the following stages:

- **Base Stage**: Uses the .NET ASP.NET 8.0 image as the base image.
- **Build Stage**: Restores, builds, and publishes the on-reader application for ARM.
- **Packaging Stage**: Packages the on-reader application into a format compatible with R700 readers.

### Commands for Docker Operations

- **Build the Docker Image**:
  ```bash
  docker build --platform=linux/arm -t onreaderapp -f ./Dockerfile ../
  ```

- **Build with Progress Output**:
  ```bash
  docker build --progress=plain --platform=linux/arm -t onreaderapp-upgx -f ./Dockerfile ../
  ```

## Output

The final output of the build process will be an onreaderapp_cap.upgx file packaged and ready to be deployed on an R700 reader. This file will be available in the cap_deploy directory.

## Troubleshooting

- Ensure Docker is running before executing the scripts.
- Check that the necessary tools and dependencies are downloaded and accessible.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.
