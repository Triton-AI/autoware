#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(readlink -f "$(dirname "$0")")
WORKSPACE_ROOT="$SCRIPT_DIR/../"
source "$WORKSPACE_ROOT/amd64.env"
if [ "$(uname -m)" = "aarch64" ]; then
    source "$WORKSPACE_ROOT/arm64.env"
fi

# Default values
option_no_nvidia=false
option_devel=false
option_headless=false
MAP_PATH=""
WORKSPACE_PATH=""
USER_ID=""
WORKSPACE=""
DEFAULT_LAUNCH_CMD="ros2 launch autoware_launch autoware.launch.xml map_path:=/autoware_map vehicle_model:=sample_vehicle sensor_model:=sample_sensor_kit"

# Function to print help message
print_help() {
    echo -e "\n------------------------------------------------------------"
    echo "Note: The --map-path option is mandatory for default launch command. Please provide exact path to the map files."
    echo "      Default launch command: ${DEFAULT_LAUNCH_CMD}"
    echo "------------------------------------------------------------"
    echo "Usage: run.sh [OPTIONS] [LAUNCH_CMD](optional)"
    echo "Options:"
    echo "  --help          Display this help message"
    echo "  -h              Display this help message"
    echo "  --map-path      Specify the path to the map files (mandatory if no custom launch command is provided)"
    echo "  --no-nvidia     Disable NVIDIA GPU support"
    echo "  --devel         Use the latest development version of Autoware"
    echo "  --headless      Run Autoware in headless mode (default: false)"
    echo "  --workspace     Specify the workspace path to mount into container(default: current directory)"
    echo ""
}

# Parse arguments
parse_arguments() {
    while [ "$1" != "" ]; do
        case "$1" in
        --help | -h)
            print_help
            exit 1
            ;;
        --no-nvidia)
            option_no_nvidia=true
            ;;
        --devel)
            option_devel=true
            ;;
        --headless)
            option_headless=true
            ;;
        --workspace)
            WORKSPACE_PATH="$2"
            shift
            ;;
        --map-path)
            MAP_PATH="$2"
            shift
            ;;
        --*)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        -*)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        *)
            LAUNCH_CMD="$@"
            break
            ;;
        esac
        shift
    done
}

# Set image and workspace variables
set_variables() {
    # Check if map path is provided for default launch command
    if [ "$MAP_PATH" == "" ] && [ "$LAUNCH_CMD" == "" ]; then
        print_help
        exit 1
    fi

    # Mount map path if provided
    MAP="-v ${MAP_PATH}:/autoware_map:ro"

    # Set default launch command if not provided
    if [ "$LAUNCH_CMD" == "" ]; then
        LAUNCH_CMD=${DEFAULT_LAUNCH_CMD}
    fi

    # Set workspace path if provided with current user and group
    if [ "$WORKSPACE_PATH" != "" ]; then
        USER_ID="-e LOCAL_UID=$(id -u) -e LOCAL_GID=$(id -g) -e LOCAL_USER=$(id -un) -e LOCAL_GROUP=$(id -gn)"
        WORKSPACE="-v ${WORKSPACE_PATH}:/workspace"
    fi

    # Set image based on option
    if [ "$option_devel" == "true" ]; then
        IMAGE="ghcr.io/autowarefoundation/autoware-openadk:devel-humble-latest-cuda"
    else
        IMAGE="ghcr.io/autowarefoundation/autoware-openadk:runtime-humble-latest-cuda"
    fi
}

# Set GPU flag based on option
set_gpu_flag() {
    if [ "$option_no_nvidia" = "true" ]; then
        IMAGE=${IMAGE}-nocuda
        GPU_FLAG=""
    else
        GPU_FLAG="--gpus all"
    fi
}

# Set X display variables
set_x_display() {
    MOUNT_X=""
    if [ "$option_headless" = "false" ]; then
        MOUNT_X="-e DISPLAY=$DISPLAY -v /tmp/.X11-unix/:/tmp/.X11-unix"
        xhost + >/dev/null
    fi
}

# Main script execution
main() {
    # Parse arguments
    parse_arguments "$@"
    set_variables
    set_gpu_flag
    set_x_display

    echo -e "\n-----------------------LAUNCHING CONTAINER-----------------------"
    echo "IMAGE: ${IMAGE}"
    echo "MAP PATH: ${MAP_PATH}"
    echo "LAUNCH CMD: ${LAUNCH_CMD}"
    echo "WORKSPACE(to mount): ${WORKSPACE_PATH}"
    echo "-----------------------------------------------------------------"

    # Launch the container
    set -x
    docker run -it --rm --net=host ${GPU_FLAG} ${USER_ID} ${MOUNT_X} \
        ${WORKSPACE} ${MAP} ${IMAGE} \
        ${LAUNCH_CMD}
}

# Execute the main script
main "$@"
